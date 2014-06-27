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
	@final var _current: T
	@final var _observers: Box<Observer>[] = []

	@final let _disposable: Disposable?

	@final var current: T {
		get {
			var value: T? = nil

			dispatch_sync(_queue) {
				value = self._current
			}

			return value!
		}
	}

	init(initialValue: T, generator: Observer -> Disposable?) {
		_current = initialValue
		_disposable = generator { value in
			dispatch_barrier_sync(self._queue) {
				self._current = value

				for sendBox in self._observers {
					sendBox.value(value)
				}
			}
		}
	}

	deinit {
		_disposable?.dispose()
	}

	@final class func constant(value: T) -> Observable<T> {
		return Observable(initialValue: value) { _ in nil }
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
			observer(self._current)
		}

		return ActionDisposable {
			dispatch_barrier_async(self._queue) {
				self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
			}
		}
	}

	// FIXME: A lot of the below operators need to skip the initial value sent
	// upon observation.

	@final override func map<U>(f: T -> U) -> Observable<U> {
		return Observable<U>(initialValue: f(self.current)) { send in
			return self.observe { value in
				send(f(value))
			}
		}
	}

	@final func replay(count: Int) -> Enumerable<T> {
		// TODO
		return .empty()
	}

	@final func filter(base: T, pred: T -> Bool) -> Observable<T> {
		return Observable(initialValue: base) { send in
			return self.observe { value in
				if pred(value) {
					send(value)
				}
			}
		}
	}

	@final func combineLatestWith<U>(stream: Observable<U>) -> Observable<(T, U)>

	@final func sampleOn<U>(sampler: Observable<U>) -> Observable<T> {
		return Observable(initialValue: current) { send in
			return sampler.observe { _ in send(self.current) }
		}
	}
}
