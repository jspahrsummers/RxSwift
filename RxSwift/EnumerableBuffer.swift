//
//  EnumerableBuffer.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A controllable Enumerable that functions as a combination push- and
/// pull-driven stream.
@final class EnumerableBuffer<T>: Enumerable<T> {
	let _capacity: Int?

	let _queue = dispatch_queue_create("com.github.ReactiveCocoa.EnumerableBuffer", DISPATCH_QUEUE_SERIAL)
	var _enumerators: Box<Enumerator>[] = []
	var _eventBuffer: Event<T>[] = []

	init(capacity: Int? = nil) {
		assert(capacity == nil || capacity! > 0)
		_capacity = capacity

		super.init(enumerate: { send in
			let box = Box(send)

			dispatch_barrier_sync(self._queue) {
				self._enumerators.append(box)

				for event in self._eventBuffer {
					send(event)
				}
			}

			return ActionDisposable {
				dispatch_barrier_async(self._queue) {
					self._enumerators = removeObjectIdenticalTo(box, fromArray: self._enumerators)
				}
			}
		})
	}

	func send(event: Event<T>) {
		dispatch_barrier_sync(_queue) {
			self._eventBuffer.append(event)
			if let capacity = self._capacity {
				while self._eventBuffer.count > capacity {
					self._eventBuffer.removeAtIndex(0)
				}
			}

			for send in self._enumerators {
				send.value(event)
			}
		}
	}
}
