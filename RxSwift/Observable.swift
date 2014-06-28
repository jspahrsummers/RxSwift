//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream that sends the same values to all observers.
class Observable<T>: Stream<T> {
	typealias Observer = T -> ()

	@final let _queue = dispatch_queue_create("com.github.ReactiveCocoa.Observable", DISPATCH_QUEUE_CONCURRENT)
	@final var _current: Box<T>? = nil
	@final var _observers: Box<Observer>[] = []

	@final var _disposable: Disposable? = nil

	var current: T {
		get {
			var value: T? = nil

			dispatch_sync(_queue) {
				value = self._current
			}

			return value!
		}
	}

	init(generator: Observer -> Disposable?) {
		super.init()

		_disposable = generator { value in
			dispatch_barrier_sync(self._queue) {
				self._current = Box(value)

				for sendBox in self._observers {
					sendBox.value(value)
				}
			}
		}

		assert(_current != nil)
	}
	
	convenience init(initialValue: T, generator: Observer -> Disposable?) {
		self.init(generator: { send in
			send(initialValue)
			return generator(send)
		})
	}

	deinit {
		_disposable?.dispose()
	}

	@final class func interval(interval: NSTimeInterval, onScheduler scheduler: RepeatableScheduler, withLeeway leeway: NSTimeInterval = 0) -> Observable<NSDate> {
		let startDate = NSDate()

		return Observable<NSDate>(initialValue: startDate) { send in
			return scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				send(NSDate())
			}
		}
	}

	@final func observe(observer: Observer) -> Disposable {
		let box = Box(observer)

		dispatch_barrier_sync(_queue) {
			self._observers.append(box)
			observer(self._current!)
		}

		return ActionDisposable {
			dispatch_barrier_async(self._queue) {
				self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
			}
		}
	}

	@final override class func unit(value: T) -> Observable<T> {
		return Observable { send in
			send(value)
			return nil
		}
	}

	@final override func mapAccumulate<S, U>(initialState: S, _ f: (S, T) -> (S?, U)) -> Observable<U> {
		return Observable<U> { send in
			let state = Atomic(initialState)
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				let (maybeState, newValue) = f(state, value)
				send(newValue)

				if let s = maybeState {
					state.value = s
				} else {
					selfDisposable.dispose()
				}
			}

			return selfDisposable
		}
	}

	@final override func removeNil<U>(evidence: Stream<T> -> Stream<U?>, initialValue: U) -> Observable<U> {
		return Observable<U>(initialValue: initialValue) { send in
			return (evidence(self) as Observable<U?>).observe { maybeValue in
				if let value = maybeValue {
					send(value)
				}
			}
		}
	}

	@final override func merge<U>(evidence: Stream<T> -> Stream<Stream<U>>) -> Observable<U> {
		return Observable<U> { send in
			let disposable = CompositeDisposable()

			let selfDisposable = (evidence(self) as Observable<Stream<U>>).observe { stream in
				let streamDisposable = (stream as Observable<U>).observe { value in
					send(value)
				}

				// FIXME: Unbounded resource growth!
				disposable.addDisposable(streamDisposable)
			}

			disposable.addDisposable(selfDisposable)
			return disposable
		}
	}

	@final override func switchToLatest<U>(evidence: Stream<T> -> Stream<Stream<U>>) -> Observable<U> {
		return Observable<U> { send in
			let compositeDisposable = CompositeDisposable()

			let latestDisposable = SerialDisposable()
			compositeDisposable.addDisposable(latestDisposable)

			let selfDisposable = (evidence(self) as Observable<Stream<U>>).observe { stream in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = (stream as Observable<U>).observe { value in send(value) }
			}

			compositeDisposable.addDisposable(selfDisposable)
			return compositeDisposable
		}
	}

	@final override func map<U>(f: T -> U) -> Observable<U> {
		return super.map(f) as Observable<U>
	}

	@final override func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Observable<U> {
		return super.scan(initialValue, f) as Observable<U>
	}

	@final override func filter(pred: T -> Bool) -> Observable<T?> {
		return super.filter(pred) as Observable<T?>
	}

	@final func filter(initialValue: T, pred: T -> Bool) -> Observable<T> {
		return self
			.filter(pred)
			.removeNil(identity, initialValue: initialValue)
	}

	@final override func take(count: Int) -> Observable<T> {
		assert(count > 0)
		return super.take(count) as Observable<T>
	}

	@final func buffer(capacity: Int? = nil) -> (Enumerable<T>, Disposable) {
		let enumerable = EnumerableBuffer<T>(capacity: capacity)

		let observationDisposable = self.observe { value in
			enumerable.send(.Next(Box(value)))
		}

		let bufferDisposable = ActionDisposable {
			observationDisposable.dispose()
			enumerable.send(.Completed)
		}

		return (enumerable, bufferDisposable)
	}

	@final func combineLatestWith<U>(stream: Observable<U>) -> Observable<(T, U)> {
		return Observable<(T, U)> { send in
			// FIXME: This implementation is probably racey.
			let selfDisposable = self.observe { value in send(value, stream.current) }
			let otherDisposable = stream.observe { value in send(self.current, value) }
			return CompositeDisposable([selfDisposable, otherDisposable])
		}
	}

	@final func sampleOn<U>(sampler: Observable<U>) -> Observable<T> {
		return Observable { send in
			return sampler.observe { _ in send(self.current) }
		}
	}
}
