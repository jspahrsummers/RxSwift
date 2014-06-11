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
	case Done(() -> T)
}

class Promise<T> {
	let condition = NSCondition()
	
	var state: PromiseState<T>
	var isResolving: Bool {
		get {
			switch self.state {
			case .Resolving:
				return true
			default:
				return false
			}
		}
	}

	init(work: () -> T) {
		self.condition.name = "com.github.RxSwift.Promise"
		self.state = .Unresolved(work);
	}
	
	func start(scheduler: Scheduler) -> Disposable? {
		return scheduler.schedule {
			let maybeWork: (() -> T)? = withLock(self.condition) {
				switch self.state {
				case let .Unresolved(work):
					self.state = .Resolving
					return work
				case let .Done(result):
					fallthrough
				case .Resolving:
					return nil
				}
			}
			
			if maybeWork == nil {
				return
			}
			
			let result = maybeWork!()
			
			withLock(self.condition) { () -> () in
				self.state = PromiseState.Done { result }
				self.condition.broadcast()
			}
		}
	}
	
	func result() -> T {
		let (maybeWork: (() -> T)?, maybeResult: T?) = withLock(self.condition) {
			while self.isResolving {
				self.condition.wait()
			}

			switch self.state {
			case let .Unresolved(work):
				self.state = .Resolving
				return (work, nil)
			case let .Done(result):
				return (nil, result())
			default:
				return (nil, nil)
			}
		}
		
		if let work = maybeWork {
			let result = work()

			withLock(self.condition) { () -> () in
				self.state = PromiseState.Done { () -> T in result }
				self.condition.broadcast()
			}

			return result
		} else {
			return maybeResult!
		}
	}
	
	func whenFinished(scheduler: Scheduler, action: T -> ()) -> Disposable? {
		return nil
	}
}
