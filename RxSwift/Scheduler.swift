//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents an action that returns a value of type T, and which can only be
/// run on a scheduler of type S.
struct ScheduledAction<T, S: Scheduler> {
	let _closure: S -> T

	init(_ closure: S -> T) {
		_closure = closure
	}
}

@infix
func >>=<S: Scheduler, T, U>(action: ScheduledAction<T, S>, f: T -> ScheduledAction<U, S>) -> ScheduledAction<U, S> {
	return ScheduledAction<U, S> { scheduler in
		let tv: T = action._closure(scheduler)
		return f(tv)._closure(scheduler)
	}
}

/// Represents a serial queue of work items.
protocol Scheduler {
	/// Enqueues an unannotated action on the scheduler.
	///
	/// When the work is executed depends on the scheduler in use.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(action: () -> ()) -> Disposable?
}

func schedule<S: Scheduler>(scheduler: S, action: ScheduledAction<(), S>) -> Disposable? {
	return scheduler.schedule { action._closure(scheduler) }
}

func getCurrentScheduler<S: Scheduler>() -> ScheduledAction<S, S> {
	return ScheduledAction{ scheduler in scheduler }
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

			action()
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
			
			work()
		})
		
		return d
	}
}
