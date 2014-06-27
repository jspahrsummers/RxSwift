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
		var generatedOnce = false

		_disposable = generator { value in
			dispatch_barrier_sync(self._queue) {
				self._current = value

				for sendBox in self._observers {
					sendBox.value(value)
				}
			}

			generatedOnce = true
		}

		assert(generatedOnce)
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

	@final class func constant(value: T) -> Observable<T> {
		return Observable { send in
			send(value)
			return nil
		}
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

	@final override func map<U>(f: T -> U) -> Observable<U> {
		return Observable<U> { send in
			return self.observe { value in
				send(f(value))
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

	@final override func scan<U>(initial: U, _ f: (U, T) -> U) -> Observable<U> {
		return Observable<U> { send in
			var state = initial

			return self.observe { value in
				let result = f(state, value)

				state = result
				send(result)
			}
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
		return Observable { send in
			return sampler.observe { _ in send(self.current) }
		}
	}
}
