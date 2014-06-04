//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

protocol Scheduler {
	func schedule(work: () -> ()) -> Disposable?
}

class ImmediateScheduler: Scheduler {
	func schedule(work: () -> ()) -> Disposable? {
		work()
		return nil
	}
}

class QueueScheduler: Scheduler {
	let queue = dispatch_queue_create("com.github.RxSwift.QueueScheduler", DISPATCH_QUEUE_SERIAL)

	init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(self.queue, queue)
	}
	
	func schedule(work: () -> ()) -> Disposable? {
		let d = SimpleDisposable()
	
		dispatch_async(self.queue, {
			if d.disposed {
				return
			}
			
			work()
		})
		
		return d
	}
}