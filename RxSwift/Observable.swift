//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream that sends the same events to all observers.
class Observable<T>: Stream<T> {
	typealias Observer = T -> ()

	let _queue = dispatch_queue_create("com.github.ReactiveCocoa.Observable", DISPATCH_QUEUE_CONCURRENT)
	var _current: T
	var _observers: Box<Observer>[] = []

	let _disposable: Disposable?

	var current: T {
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

	class func constant(value: T) -> Observable<T> {
		return Observable(initialValue: value) { _ in nil }
	}

	class func interval(interval: NSTimeInterval, onScheduler: RepeatableScheduler, withLeeway: NSTimeInterval = 0) -> Signal<NSDate>

	func observe(observer: Observer) -> Disposable {
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

	func replay(count: Int) -> Enumerable<T>

	func filter(base: T, pred: T -> Bool) -> Observable<T>
	func combineLatestWith<U>(stream: Observable<U>) -> Observable<(T, U)>
	func sampleOn<U>(sampler: Observable<U>) -> Observable<T>
}
