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
	
	var isResolving: Bool {
		get {
			switch self {
			case .Resolving:
				return true
			default:
				return false
			}
		}
	}
}

class Promise<T> {
	let condition = NSCondition()
	var finishedActions: (() -> ())[] = []
	
	var state: PromiseState<T> {
		willSet(newState) {
			switch newState {
			case .Done:
				for action in self.finishedActions {
					action()
				}
				
				self.finishedActions = []
				self.condition.broadcast()
				
			default:
				break
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
			}
		}
	}
	
	func result() -> T {
		let (maybeWork: (() -> T)?, maybeResult: T?) = withLock(self.condition) {
			while self.state.isResolving {
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
			}

			return result
		} else {
			return maybeResult!
		}
	}
	
	func whenFinished(scheduler: Scheduler, action: T -> ()) -> Disposable? {
		return withLock(self.condition) {
			switch self.state {
			case let .Done(result):
				return scheduler.schedule {
					action(result())
				}
			
			default:
				let disposable = CompositeDisposable()
			
				// TODO: Offer a way to remove this from the array too?
				self.finishedActions.append {
					let schedulerDisposable = scheduler.schedule {
						action(self.result())
					}
					
					disposable.addDisposable(schedulerDisposable)
				}
				
				return disposable
			}
		}
	}
}
