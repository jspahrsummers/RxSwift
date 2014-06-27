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

	@final let _enumerate: Enumerator -> Disposable?
	init(_ enumerate: Enumerator -> Disposable?) {
		_enumerate = enumerate
	}

	@final class func empty() -> Enumerable<T> {
		return Enumerable { send in
			send(.Completed)
			return nil
		}
	}

	@final class func single(value: T) -> Enumerable<T> {
		return Enumerable { send in
			send(.Next(Box(value)))
			send(.Completed)
			return nil
		}
	}

	@final class func error(error: NSError) -> Enumerable<T> {
		return Enumerable { send in
			send(.Error(error))
			return nil
		}
	}

	@final class func never() -> Enumerable<T> {
		return Enumerable { _ in nil }
	}

	@final func enumerate(enumerator: Enumerator) -> Disposable? {
		return _enumerate(enumerator)
	}

	@final override func map<U>(f: T -> U) -> Enumerable<U> {
		return Enumerable<U> { send in
			return self.enumerate { event in
				switch event {
				case let .Next(value):
					let mapped = f(value)
					send(.Next(Box(mapped)))

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					send(.Completed)
				}
			}
		}
	}

	@final func first() -> Event<T> {
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

	@final func waitUntilCompleted() -> Event<()> {
		return ignoreValues().first()
	}

	@final func filter(pred: T -> Bool) -> Enumerable<T>
	@final func concat(stream: Enumerable<T>) -> Enumerable<T>
	@final func take(count: Int) -> Enumerable<T>
	@final func takeWhile(pred: T -> Bool) -> Enumerable<T>
	@final func takeLast(count: Int) -> Enumerable<T>
	@final func skip(count: Int) -> Enumerable<T>
	@final func skipWhile(pred: T -> Bool) -> Enumerable<T>

	@final func materialize() -> Enumerable<Event<T>> {
		return Enumerable<Event<T>> { send in
			return self.enumerate { event in
				send(.Next(Box(event)))

				if event.isTerminating {
					send(.Completed)
				}
			}
		}
	}

	@final func dematerialize<U, EV: TypeEquality where EV.From == T, EV.To == Enumerable<Event<U>>>(ev: EV) -> Enumerable<U>

	@final func catch(f: NSError -> Enumerable<T>) -> Enumerable<T> {
		return Enumerable { send in
			let serialDisposable = SerialDisposable()

			serialDisposable.innerDisposable = self.enumerate { event in
				switch event {
				case let .Error(error):
					let newStream = f(error)
					serialDisposable.innerDisposable = newStream.enumerate(send)

				default:
					send(event)
				}
			}

			return serialDisposable
		}
	}

	@final func aggregate<U>(initial: U, _ f: (U, T) -> U) -> Enumerable<U>

	@final func ignoreValues() -> Enumerable<()> {
		return Enumerable<()> { send in
			return self.enumerate { event in
				switch event {
				case let .Next(value):
					break

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					send(.Completed)
				}
			}
		}
	}

	@final func doEvent(action: Event<T> -> ()) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				action(event)
				send(event)
			}
		}
	}

	@final func doDisposed(action: () -> ()) -> Enumerable<T> {
		return Enumerable { send in
			let disposable = CompositeDisposable()
			disposable.addDisposable(ActionDisposable(action))
			disposable.addDisposable(self.enumerate(send))
			return disposable
		}
	}

	@final func collect() -> Enumerable<SequenceOf<T>>
	@final func timeout(interval: NSTimeInterval, onScheduler: Scheduler) -> Enumerable<T>

	@final func enumerateOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				scheduler.schedule { send(event) }
				return ()
			}
		}
	}
}
