//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream that sends the same values to all observers.
class Observable<T> {
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

	@final class func constant(value: T) -> Observable<T> {
		return Observable { send in
			send(value)
			return nil
		}
	}

	@final func ignoreNil<U>(evidence: Observable<T> -> Observable<U?>, initialValue: U) -> Observable<U> {
		return Observable<U>(initialValue: initialValue) { send in
			return evidence(self).observe { maybeValue in
				if let value = maybeValue {
					send(value)
				}
			}
		}
	}

	@final func merge<U>(evidence: Observable<T> -> Observable<Observable<U>>) -> Observable<U> {
		return Observable<U> { send in
			let disposable = CompositeDisposable()

			let selfDisposable = evidence(self).observe { stream in
				let streamDisposable = stream.observe { value in
					send(value)
				}

				// FIXME: Unbounded resource growth!
				disposable.addDisposable(streamDisposable)
			}

			disposable.addDisposable(selfDisposable)
			return disposable
		}
	}

	@final func switchToLatest<U>(evidence: Observable<T> -> Observable<Observable<U>>) -> Observable<U> {
		return Observable<U> { send in
			let compositeDisposable = CompositeDisposable()

			let latestDisposable = SerialDisposable()
			compositeDisposable.addDisposable(latestDisposable)

			let selfDisposable = evidence(self).observe { stream in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = stream.observe { value in send(value) }
			}

			compositeDisposable.addDisposable(selfDisposable)
			return compositeDisposable
		}
	}

	@final func map<U>(f: T -> U) -> Observable<U> {
		return Observable<U> { send in
			return self.observe { value in send(f(value)) }
		}
	}

	@final func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Observable<U> {
		let previous = Atomic(initialValue)

		return Observable<U> { send in
			return self.observe { value in
				let newValue = f(previous.value, value)
				send(newValue)

				previous.value = newValue
			}
		}
	}

	@final func take(count: Int) -> Observable<T> {
		assert(count > 0)

		let soFar = Atomic(0)

		return Observable { send in
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				let orig = soFar.modify { $0 + 1 }
				if orig < count {
					send(value)
				} else {
					selfDisposable.dispose()
				}
			}

			return selfDisposable
		}
	}

	@final func takeWhile(initialValue: T, _ pred: T -> Bool) -> Observable<T> {
		return Observable(initialValue: initialValue) { send in
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				if pred(value) {
					send(value)
				} else {
					selfDisposable.dispose()
				}
			}

			return selfDisposable
		}
	}

	@final func combinePrevious(initialValue: T) -> Observable<(T, T)> {
		let previous = Atomic(initialValue)

		return Observable<(T, T)> { send in
			return self.observe { value in
				let orig = previous.swap(value)
				send((orig, value))
			}
		}
	}

	@final func skip(count: Int) -> Observable<T?> {
		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	@final func skipWhile(pred: T -> Bool) -> Observable<T?> {
		return Observable<T?>(initialValue: nil) { send in
			let skipping = Atomic(true)

			return self.observe { value in
				if skipping.value && pred(value) {
					send(nil)
				} else {
					skipping.value = false
					send(value)
				}
			}
		}
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

	@final func filter(initialValue: T, pred: T -> Bool) -> Observable<T> {
		return Observable(initialValue: initialValue) { send in
			return self.observe { value in
				if pred(value) {
					send(value)
				}
			}
		}
	}

	@final func skipRepeats<U: Equatable>(evidence: Observable<T> -> Observable<U>) -> Observable<U> {
		return Observable<U> { send in
			let maybePrevious = Atomic<U?>(nil)

			return evidence(self).observe { current in
				if let previous = maybePrevious.swap(current) {
					if current == previous {
						return
					}
				}

				send(current)
			}
		}
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

	@final func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Observable<T?> {
		return Observable<T?>(initialValue: nil) { send in
			return self.observe { value in
				scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) { send(value) }
				return ()
			}
		}
	}

	@final func deliverOn(scheduler: Scheduler) -> Observable<T?> {
		return Observable<T?>(initialValue: nil) { send in
			return self.observe { value in
				scheduler.schedule { send(value) }
				return ()
			}
		}
	}
}
