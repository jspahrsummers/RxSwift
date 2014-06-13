//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream of values.
class Observable<T>: Stream<T> {
	/// The type of a consumer for the stream's events.
	typealias Observer = Event<T> -> ()
	
	let _observe: Observer -> Disposable?
	init(_ observe: Observer -> Disposable?) {
		self._observe = observe
	}
	
	let _observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var _observers: Box<Observer>[] = []
 
	/// Observes the stream for new events.
	///
	/// Returns a disposable which can be used to cease observation.
	func observe(observer: Observer) -> Disposable {
		let box = Box(observer)
	
		dispatch_sync(_observerQueue, {
			self._observers.append(box)
		})
		
		self._observe(box.value)
		
		return ActionDisposable {
			dispatch_sync(self._observerQueue, {
				self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
			})
		}
	}

	/// Buffers all new events into a sequence which can be enumerated
	/// on-demand.
	///
	/// Returns the buffered sequence, and a disposable which can be used to
	/// stop buffering further events.
	func replay() -> (AsyncSequence<T>, Disposable) {
		let s = AsyncSequence<T>()
		return (s, self.observe(s.send))
	}
	
	override class func empty() -> Observable<T> {
		return Observable { send in
			send(.Completed)
			return nil
		}
	}
	
	override class func single(value: T) -> Observable<T> {
		return Observable { send in
			send(.Next(Box(value)))
			return nil
		}
	}

	override func flattenScan<S, U>(initial: S, f: (S, T) -> (S?, Stream<U>)) -> Observable<U> {
		return Observable<U> { send in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)
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
}
