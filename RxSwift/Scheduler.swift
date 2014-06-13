//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
@class_protocol
protocol Scheduler {
	/// Enqueues the given work item.
	///
	/// When the work is executed depends on the specific implementation.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(work: () -> ()) -> Disposable?
}

/// A scheduler that performs all work synchronously.
class ImmediateScheduler: Scheduler {
	func schedule(work: () -> ()) -> Disposable? {
		work()
		return nil
	}
}

/// A scheduler backed by a serial GCD queue.
class QueueScheduler: Scheduler {
	let _queue = dispatch_queue_create("com.github.RxSwift.QueueScheduler", DISPATCH_QUEUE_SERIAL)

	struct _Shared {
		static let mainThreadScheduler = QueueScheduler(dispatch_get_main_queue())
	}

	/// A specific kind of QueueScheduler that will run its work items on the
	/// main thread.
	class var mainThreadScheduler: QueueScheduler {
		get {
			return _Shared.mainThreadScheduler
		}
	}

	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(_queue, queue)
	}
	
	/// Initializes a scheduler that will target the global queue with the given
	/// priority.
	convenience init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}
	
	/// Initializes a scheduler that will target the default priority global
	/// queue.
	convenience init() {
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
