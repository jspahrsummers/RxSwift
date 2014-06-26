//
//  Enumerable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A combination push/pull stream that executes work when an enumerator is
/// attached.
class Enumerable<T>: Stream<T> {
	typealias Enumerator = Event<T> -> ()

	let _enumerate: Enumerator -> Disposable?
	init(_ enumerate: Enumerator -> Disposable?) {
		_enumerate = enumerate
	}

	class func empty() -> Enumerable<T> {
		return Enumerable { send in
			send(.Completed)
			return nil
		}
	}

	class func single(value: T) -> Enumerable<T> {
		return Enumerable { send in
			send(.Next(Box(value)))
			send(.Completed)
			return nil
		}
	}

	class func error(error: NSError) -> Enumerable<T> {
		return Enumerable { send in
			send(.Error(error))
			return nil
		}
	}

	class func never() -> Enumerable<T> {
		return Enumerable { _ in nil }
	}

	func enumerate(enumerator: Enumerator) -> Disposable? {
		return _enumerate(enumerator)
	}

	func first() -> Event<T> {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Enumerable.first"

		var event: Event<T>? = nil
		take(1).enumerate { ev in
			withLock(cond) {
				event = ev
				cond.signal()
			}
		}

		return withLock(cond) {
			while event == nil {
				cond.wait()
			}

			return event!
		}
	}

	func waitUntilCompleted() -> Event<()> {
		return ignoreValues().first()
	}

	func filter(pred: T -> Bool) -> Enumerable<T>
	func concat(stream: Enumerable<T>) -> Enumerable<T>
	func take(count: Int) -> Enumerable<T>
	func takeWhile(pred: T -> Bool) -> Enumerable<T>
	func takeLast(count: Int) -> Enumerable<T>
	func skip(count: Int) -> Enumerable<T>
	func skipWhile(pred: T -> Bool) -> Enumerable<T>
	func materialize() -> Enumerable<Event<T>>
	func dematerialize<U, EV: TypeEquality where EV.From == T, EV.To == Enumerable<Event<U>>>(ev: EV) -> Enumerable<U>
	func catch(f: NSError -> Enumerable<T>) -> Enumerable<T>
	func aggregate<U>(initial: U, _ f: (U, T) -> U) -> Enumerable<U>
	func ignoreValues() -> Enumerable<()>
	func doEvent(action: Event<T> -> ()) -> Enumerable<T>
	func doDisposed(action: () -> ()) -> Enumerable<T>
	func collect() -> Enumerable<SequenceOf<T>>
	func timeout(interval: NSTimeInterval, onScheduler: Scheduler) -> Enumerable<T>

	func enumerateOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				scheduler.schedule { send(event) }
				return ()
			}
		}
	}
}
