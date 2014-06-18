//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
protocol Scheduler {
	/// Enqueues an action on the scheduler.
	///
	/// When the work is executed depends on the scheduler in use.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(action: () -> ()) -> Disposable?
}

let currentSchedulerKey = "RxSwiftCurrentSchedulerKey"

/// Returns the scheduler upon which the calling code is executing, if any.
var currentScheduler: Scheduler? {
	get {
		return NSThread.currentThread().threadDictionary[currentSchedulerKey] as? Box<Scheduler>
	}
}

/// Performs an action while setting `currentScheduler` to the given
/// scheduler instance.
func _asCurrentScheduler<T>(scheduler: Scheduler, action: () -> T) -> T {
	let previousScheduler = currentScheduler

	NSThread.currentThread().threadDictionary[currentSchedulerKey] = Box(scheduler)
	let result = action()
	NSThread.currentThread().threadDictionary[currentSchedulerKey] = Box(previousScheduler)

	return result
}

/// A scheduler that performs all work synchronously.
struct ImmediateScheduler: Scheduler {
	func schedule(action: () -> ()) -> Disposable? {
		action()
		return nil
	}
}

/// A scheduler that performs all work on the main thread.
struct MainScheduler: Scheduler {
	func schedule(action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()

		dispatch_async(dispatch_get_main_queue(), {
			if d.disposed {
				return
			}

			_asCurrentScheduler(self, action)
		})

		return d
	}
}

/// A scheduler backed by a serial GCD queue.
struct QueueScheduler: Scheduler {
	let _queue = dispatch_queue_create("com.github.RxSwift.QueueScheduler", DISPATCH_QUEUE_SERIAL)

	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(_queue, queue)
	}
	
	/// Initializes a scheduler that will target the global queue with the given
	/// priority.
	init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}
	
	/// Initializes a scheduler that will target the default priority global
	/// queue.
	init() {
		self.init(DISPATCH_QUEUE_PRIORITY_DEFAULT)
	}
	
	func schedule(work: () -> ()) -> Disposable? {
		let d = SimpleDisposable()
	
		dispatch_async(_queue, {
			if d.disposed {
				return
			}
			
			_asCurrentScheduler(self, work)
		})
		
		return d
	}
}
