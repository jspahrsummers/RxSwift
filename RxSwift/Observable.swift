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
	/// Something capable of observing the value changes of an Observable.
	typealias Observer = T -> ()

	@final let _queue = dispatch_queue_create("com.github.ReactiveCocoa.Observable", DISPATCH_QUEUE_CONCURRENT)
	@final var _current: Box<T>? = nil
	@final var _observers: Box<Observer>[] = []

	@final var _disposable: Disposable? = nil

	/// The current (most recent) value of the Observable.
	var current: T {
		get {
			var value: T? = nil

			dispatch_sync(_queue) {
				value = self._current
			}

			return value!
		}
	}

	/// Initializes an Observable that will run the given action immediately, to
	/// observe all changes.
	///
	/// `generator` _must_ yield at least one value synchronously, as
	/// Observables can never have a null current value.
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
	
	/// Initializes an Observable with the given default value, and an action to
	/// perform to begin observing future changes.
	convenience init(initialValue: T, generator: Observer -> Disposable?) {
		self.init(generator: { send in
			send(initialValue)
			return generator(send)
		})
	}

	deinit {
		_disposable?.dispose()
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	@final class func interval(interval: NSTimeInterval, onScheduler scheduler: RepeatableScheduler, withLeeway leeway: NSTimeInterval = 0) -> Observable<NSDate> {
		let startDate = NSDate()

		return Observable<NSDate>(initialValue: startDate) { send in
			return scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				send(NSDate())
			}
		}
	}

	/// Notifies `observer` about all changes to the receiver's value.
	///
	/// Returns a Disposable which can be disposed of, to stop notifying
	/// `observer` of future changes.
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

	/// Creates an Observable that will always have the same value.
	@final class func constant(value: T) -> Observable<T> {
		return Observable { send in
			send(value)
			return nil
		}
	}

	/// Resolves all Optional values in the stream, ignoring any that are `nil`.
	///
	/// evidence     - Used to prove to the typechecker that the receiver is
	///                a stream of optionals. Simply pass in the `identity`
	///                function.
	/// initialValue - A default value for the returned stream, in case the
	///                receiver's current value is `nil`, which would otherwise
	///                result in a null value for the returned stream.
	@final func ignoreNil<U>(evidence: Observable<T> -> Observable<U?>, initialValue: U) -> Observable<U> {
		return Observable<U>(initialValue: initialValue) { send in
			return evidence(self).observe { maybeValue in
				if let value = maybeValue {
					send(value)
				}
			}
		}
	}

	/// Merges an Observable of Observables into a single stream, biased toward
	/// the Observables added earlier.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns an Observable that will forward changes from the original streams
	/// as they arrive, starting with earlier ones.
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

	/// Switches on an Observable of Observables, forwarding values from the
	/// latest inner stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns an Observable that will forward changes only from the latest
	/// Observable sent upon the receiver.
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

	/// Maps each value in the stream to a new value.
	@final func map<U>(f: T -> U) -> Observable<U> {
		return Observable<U> { send in
			return self.observe { value in send(f(value)) }
		}
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
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

	/// Returns a stream that will yield the first `count` values from the
	/// receiver, where `count` is greater than zero.
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

	/// Returns a stream that will yield values from the receiver while `pred`
	/// remains `true`, starting with `initialValue` (in case the predicate
	/// fails on the receiver's current value).
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

	/// Combines each value in the stream with its preceding value, starting
	/// with `initialValue`.
	@final func combinePrevious(initialValue: T) -> Observable<(T, T)> {
		let previous = Atomic(initialValue)

		return Observable<(T, T)> { send in
			return self.observe { value in
				let orig = previous.swap(value)
				send((orig, value))
			}
		}
	}

	/// Returns a stream that will replace the first `count` values from the
	/// receiver with `nil`, then forward everything afterward.
	@final func skip(count: Int) -> Observable<T?> {
		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Returns a stream that will replace values from the receiver with `nil`
	/// while `pred` remains `true`, then forward everything afterward.
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

	/// Buffers values yielded by the receiver, preserving them for future
	/// enumeration.
	///
	/// capacity - If not nil, the maximum number of values to buffer. If more
	///            are received, the earliest values are dropped and won't be
	///            enumerated over in the future.
	///
	/// Returns an Enumerable over the buffered values, and a Disposable which
	/// can be used to cancel all further buffering.
	@final func buffer(capacity: Int? = nil) -> (Enumerable<T>, Disposable) {
		let enumerable = EnumerableBuffer<T>(capacity: capacity)

		let observationDisposable = self.observe { value in
			enumerable.send(.Next(Box(value)))
		}

		let bufferDisposable = ActionDisposable {
			observationDisposable.dispose()

			// FIXME: This violates the buffer size, since it will now only
			// contain N - 1 values.
			enumerable.send(.Completed)
		}

		return (enumerable, bufferDisposable)
	}

	/// Preserves only the values of the stream that pass the given predicate,
	/// starting with `initialValue` (in case the predicate fails on the
	/// receiver's current value).
	@final func filter(initialValue: T, pred: T -> Bool) -> Observable<T> {
		return Observable(initialValue: initialValue) { send in
			return self.observe { value in
				if pred(value) {
					send(value)
				}
			}
		}
	}

	/// Skips all consecutive, repeating values in the stream, forwarding only
	/// the first occurrence.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            values which are `Equatable`. Simply pass in the `identity`
	///            function.
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

	/// Combines the receiver with the given stream, forwarding the latest
	/// updates to either.
	///
	/// Returns an Observable which will send a new value whenever the receiver
	/// or `stream` changes.
	@final func combineLatestWith<U>(stream: Observable<U>) -> Observable<(T, U)> {
		return Observable<(T, U)> { send in
			// FIXME: This implementation is probably racey.
			let selfDisposable = self.observe { value in send(value, stream.current) }
			let otherDisposable = stream.observe { value in send(self.current, value) }
			return CompositeDisposable([selfDisposable, otherDisposable])
		}
	}

	/// Forwards the current value from the receiver whenever `sampler` sends
	/// a value.
	@final func sampleOn<U>(sampler: Observable<U>) -> Observable<T> {
		return Observable { send in
			return sampler.observe { _ in send(self.current) }
		}
	}

	/// Delays values by the given interval, forwarding them on the given
	/// scheduler.
	///
	/// Returns an Observable that will default to `nil`, then send the
	/// receiver's values after injecting the specified delay.
	@final func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Observable<T?> {
		return Observable<T?>(initialValue: nil) { send in
			return self.observe { value in
				scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) { send(value) }
				return ()
			}
		}
	}

	/// Yields all values on the given scheduler, instead of whichever
	/// scheduler they originally changed upon.
	///
	/// Returns an Observable that will default to `nil`, then send the
	/// receiver's values after being scheduled.
	@final func deliverOn(scheduler: Scheduler) -> Observable<T?> {
		return Observable<T?>(initialValue: nil) { send in
			return self.observe { value in
				scheduler.schedule { send(value) }
				return ()
			}
		}
	}

	/// Blocks indefinitely, waiting for the given predicate to be true.
	///
	/// Returns the first value that passes.
	@final func firstPassingTest(pred: T -> Bool) -> T {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Observable.firstPassingTest"

		var matchingValue: T? = nil
		observe { value in
			if !pred(value) {
				return
			}

			withLock(cond) { () -> () in
				matchingValue = value
				cond.signal()
			}
		}

		return withLock(cond) {
			while matchingValue == nil {
				cond.wait()
			}

			return matchingValue!
		}
	}
}
