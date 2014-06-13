//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Observable<T>: Stream<T> {
	typealias Observer = Event<T> -> ()
	
	let _observe: Observer -> Disposable?
	init(_ observe: Observer -> Disposable?) {
		self._observe = observe
	}
	
	let observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var observers: Box<Observer>[] = []
 
	func observe(observer: Observer) -> Disposable {
		let box = Box(observer)
	
		dispatch_sync(self.observerQueue, {
			self.observers.append(box)
		})
		
		self._observe(box.value)
		
		return ActionDisposable {
			dispatch_sync(self.observerQueue, {
				self.observers = removeObjectIdenticalTo(box, fromArray: self.observers)
			})
		}
	}
	
	override class func empty() -> Observable<T> {
		return Observable { send in
			send(.Completed)
			return nil
		}
	}
	
	override class func single(x: T) -> Observable<T> {
		return Observable { send in
			send(.Next(Box(x)))
			return nil
		}
	}

	override func flattenScan<S, U>(initial: S, f: (S, T) -> (S?, Stream<U>)) -> Observable<U> {
		return Observable<U> { send in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			// TODO: Thread safety
			var state = initial

			func decrementInFlight() {
				let rem = inFlight.modify { $0 - 1 }
				if rem == 0 {
					send(.Completed)
				}
			}

			let selfDisposable = SerialDisposable()
			disposable.addDisposable(selfDisposable)

			selfDisposable.innerDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					let (newState, stream) = f(state, value)

					if let s = newState {
						state = s
					} else {
						selfDisposable.dispose()
					}

					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					streamDisposable.innerDisposable = (stream as Observable<U>).observe { event in
						if event.isTerminating {
							disposable.removeDisposable(streamDisposable)
						}

						switch event {
						case let .Completed:
							decrementInFlight()

						default:
							send(event)
						}
					}

					break

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					decrementInFlight()
				}
			}

			return disposable
		}
	}

	func replay() -> (AsyncSequence<T>, Disposable) {
		let buf = AsyncBuffer<T>()
		return (buf, self.observe(buf.send))
	}
}
