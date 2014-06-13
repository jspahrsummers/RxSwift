//
//  Promise.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

enum PromiseState<T> {
	case Unresolved(() -> T)
	case Resolving
	case Done(Box<T>)
	
	var isResolving: Bool {
		get {
			switch self {
			case let .Resolving:
				return true
				
			default:
				return false
			}
		}
	}
}

class Promise<T> {
    let _queue = dispatch_queue_create("com.github.RxSwift.Promise", DISPATCH_QUEUE_CONCURRENT)
	let _suspended = Atomic(true)

	var _result: Box<T>? = nil

	init(_ work: () -> T, targetQueue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
		dispatch_set_target_queue(self._queue, targetQueue)
		dispatch_suspend(self._queue)
		
		dispatch_barrier_async(self._queue) {
			self._result = Box(work())
		}
	}
	
	func start() {
		self._suspended.modify { b in
			if b {
				dispatch_resume(self._queue)
			}
			
			return false
		}
	}
	
	func result() -> T {
		self.start()
		
		// Wait for the work to finish.
		dispatch_sync(self._queue) {}
		
		return self._result!
	}
	
	func whenFinished(action: T -> ()) -> Disposable {
		let disposable = SimpleDisposable()
		
		dispatch_async(self._queue) {
			if disposable.disposed {
				return
			}
		
			action(self._result!)
		}
		
		return disposable
	}
}
