//
//  Promise.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// TODO: This lives outside of the definition below because of an infinite loop
// in the compiler. Move it back within Promise once that's fixed.
enum _PromiseState<T, S: Scheduler> {
	case Unresolved(S -> T)
	case Resolving
	case Resolved(Box<T>)
}

/// Represents deferred work to generate a value of type T, which must run on
/// a scheduler of type S.
@final class Promise<T, S: Scheduler> {
	let _state: Atomic<_PromiseState<T, S>>
	let _notifyingGroup = dispatch_group_create()

	/// Returns the generated result of the promise, or nil if it hasn't been
	/// resolved yet.
	var result: T? {
		get {
			switch _state.value {
			case let .Resolved(result):
				return result

			default:
				return nil
			}
		}
	}

	/// Initializes a constant promise.
	init(_ value: T) {
		_state = Atomic(.Resolved(Box(value)))
	}

	/// Initializes a promise that will generate a value using the given
	/// function.
	init(scheduledAction: S -> T) {
		_state = Atomic(.Unresolved(scheduledAction))
		dispatch_group_enter(_notifyingGroup)
	}

	convenience init(_ work: () -> T) {
		self.init(scheduledAction: { scheduler in work() })
	}

	/// Starts resolving the promise, if it hasn't been started already.
	func startOn(scheduler: S) {
		_startOn(scheduler, shouldSchedule: true)
	}

	func _startOn(scheduler: S, shouldSchedule: Bool) {
		let (_, maybeWork: (S -> T)?) = _state.modify { s in
			switch s {
			case let .Unresolved(work):
				return (.Resolving, work)

			default:
				return (s, nil)
			}
		}

		if let work = maybeWork {
			let action: () -> () = {
				let result = work(scheduler)
				self._state.value = .Resolved(Box(result))

				dispatch_group_leave(self._notifyingGroup)
			}

			if (shouldSchedule) {
				scheduler.schedule(action)
			} else {
				action()
			}
		}
	}
	
	/// Blocks on the result of the promise.
	///
	/// This function does not actually start resolving the promise. Use startOn()
	/// for that.
	func await() -> T {
		dispatch_group_wait(_notifyingGroup, DISPATCH_TIME_FOREVER)
		return result!
	}
	
	/// Enqueues the given action to be performed when the promise finishes
	/// resolving.
	///
	/// This does not start the promise.
	///
	/// Returns a disposable that can be used to cancel the action before it
	/// runs.
	func notifyOn(queue: dispatch_queue_t, _ action: T -> ()) -> Disposable {
		let disposable = SimpleDisposable()
		
		dispatch_group_notify(_notifyingGroup, queue) {
			if disposable.disposed {
				return
			}
		
			action(self.result!)
		}
		
		return disposable
	}

	/// Creates a promise that will resolve the receiver, then map over the
	/// result.
	func map<U>(f: T -> U) -> Promise<U, S> {
		return Promise<U, S>(scheduledAction: { scheduler in
			self._startOn(scheduler, shouldSchedule: false)
			return f(self.result!)
		})
	}

	/// Creates a promise that will resolve the receiver, then also the promise
	/// returned from the given function, and yield the result of the latter.
	func then<U>(f: T -> Promise<U, S>) -> Promise<U, S> {
		return Promise<U, S>(scheduledAction: { scheduler in
			self._startOn(scheduler, shouldSchedule: false)

			let p = f(self.result!)
			p._startOn(scheduler, shouldSchedule: false)

			return p.result!
		})
	}
}

/// Returns a Promise that identifies the scheduler it is being evaluated
/// within.
func getCurrentScheduler<S: Scheduler>() -> Promise<S, S> {
	return Promise { scheduler in scheduler }
}

operator prefix |- {}

@prefix
func |-<T, S>(f: @auto_closure () -> T) -> Promise<T, S> {
	return Promise { f() }
}

@prefix
func |-<T, S>(f: @auto_closure () -> Promise<T, S>) -> Promise<T, S> {
	return f()
}

@infix
func |<T, U, S>(p: Promise<T, S>, f: (T -> Promise<U, S>)) -> Promise<U, S> {
	return p.then(f)
}

@infix
func |<T, U, S>(p: Promise<T, S>, f: (T -> U)) -> Promise<U, S> {
	return p.map(f)
}

@infix
func |<T, U, S>(p: Promise<T, S>, f: @auto_closure () -> Promise<U, S>) -> Promise<U, S> {
	return p.then { _ in f() }
}

@infix
func |<T, U, S>(p: Promise<T, S>, f: @auto_closure () -> U) -> Promise<U, S> {
	return p.map { _ in f() }
}
