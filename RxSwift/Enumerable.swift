//
//  Enumerable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A pull-driven stream that executes work when an enumerator is attached.
class Enumerable<T> {
	typealias Enumerator = Event<T> -> ()

	@final let _enumerate: Enumerator -> Disposable?
	init(enumerate: Enumerator -> Disposable?) {
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

	@final func mapAccumulate<S, U>(initialState: S, _ f: (S, T) -> (S?, U)) -> Enumerable<U> {
		return Enumerable<U> { send in
			let state = Atomic(initialState)

			return self.enumerate { event in
				switch event {
				case let .Next(value):
					let (maybeState, newValue) = f(state, value)
					send(.Next(Box(newValue)))

					if let s = maybeState {
						state.value = s
					} else {
						send(.Completed)
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					send(.Completed)
				}
			}
		}
	}

	@final func removeNil<U>(evidence: Enumerable<T> -> Enumerable<U?>) -> Enumerable<U> {
		return Enumerable<U> { send in
			return evidence(self).enumerate { event in
				switch event {
				case let .Next(maybeValue):
					if let value = maybeValue.value {
						send(.Next(Box(value)))
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					send(.Completed)
				}
			}
		}
	}

	@final func merge<U>(evidence: Enumerable<T> -> Enumerable<Enumerable<U>>) -> Enumerable<U> {
		return Enumerable<U> { send in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			func decrementInFlight() {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					send(.Completed)
				}
			}

			let selfDisposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(stream):
					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					streamDisposable.innerDisposable = stream.value.enumerate { event in
						if event.isTerminating {
							disposable.removeDisposable(streamDisposable)
						}

						switch event {
						case let .Completed:
							decrementInFlight()

						default:
							send(event)
						}
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					decrementInFlight()
				}
			}

			disposable.addDisposable(selfDisposable)
			return disposable
		}
	}

	@final func switchToLatest<U>(evidence: Enumerable<T> -> Enumerable<Enumerable<U>>) -> Enumerable<U> {
		return Enumerable<U> { send in
			let selfCompleted = Atomic(false)
			let latestCompleted = Atomic(false)

			func completeIfNecessary() {
				if selfCompleted.value && latestCompleted.value {
					send(.Completed)
				}
			}

			let compositeDisposable = CompositeDisposable()

			let latestDisposable = SerialDisposable()
			compositeDisposable.addDisposable(latestDisposable)

			let selfDisposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(stream):
					latestDisposable.innerDisposable = nil
					latestDisposable.innerDisposable = stream.value.enumerate { innerEvent in
						switch innerEvent {
						case let .Completed:
							latestCompleted.value = true
							completeIfNecessary()

						default:
							send(innerEvent)
						}
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					selfCompleted.value = true
					completeIfNecessary()
				}
			}

			compositeDisposable.addDisposable(selfDisposable)
			return compositeDisposable
		}
	}

	@final func map<U>(f: T -> U) -> Enumerable<U> {
		return mapAccumulate(()) { (_, value) in
			return ((), f(value))
		}
	}

	@final func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Enumerable<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	@final func take(count: Int) -> Enumerable<T> {
		if count == 0 {
			return .empty()
		}

		return mapAccumulate(0) { (n, value) in
			let newN: Int? = (n + 1 < count ? n + 1 : nil)
			return (newN, value)
		}
	}

	@final func takeWhile(pred: T -> Bool) -> Enumerable<T> {
		return self
			.mapAccumulate(true) { (taking, value) in
				if taking && pred(value) {
					return (true, .single(value))
				} else {
					return (nil, .empty())
				}
			}
			.merge(identity)
	}

	@final func combinePrevious(initialValue: T) -> Enumerable<(T, T)> {
		return mapAccumulate(initialValue) { (previous, current) in
			return (current, (previous, current))
		}
	}

	@final func skip(count: Int) -> Enumerable<T> {
		return self
			.mapAccumulate(0) { (n, value) in
				if n >= count {
					return (count, .single(value))
				} else {
					return (n + 1, .empty())
				}
			}
			.merge(identity)
	}

	@final func skipWhile(pred: T -> Bool) -> Enumerable<T> {
		return self
			.mapAccumulate(true) { (skipping, value) in
				if !skipping || !pred(value) {
					return (false, .single(value))
				} else {
					return (true, .empty())
				}
			}
			.merge(identity)
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

	@final func bindToProperty(property: ObservableProperty<T>) -> Disposable? {
		return self.enumerate { event in
			switch event {
			case let .Next(value):
				property.current = value

			case let .Error(error):
				assert(false)

			default:
				break
			}
		}
	}

	@final func filter(pred: T -> Bool) -> Enumerable<T> {
		return self
			.map { value -> Enumerable<T> in
				if pred(value) {
					return .single(value)
				} else {
					return .empty()
				}
			}
			.merge(identity)
	}

	@final func skipRepeats<U: Equatable>(evidence: Enumerable<T> -> Enumerable<U>) -> Enumerable<U> {
		return evidence(self)
			.mapAccumulate(nil) { (maybePrevious: U?, current: U) -> (U??, Enumerable<U>) in
				if let previous = maybePrevious {
					if current == previous {
						return (current, .empty())
					}
				}

				return (current, .single(current))
			}
			.merge(identity)
	}

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

	@final func dematerialize<U>(evidence: Enumerable<T> -> Enumerable<Event<U>>) -> Enumerable<U> {
		return Enumerable<U> { send in
			return evidence(self).enumerate { event in
				switch event {
				case let .Next(innerEvent):
					send(innerEvent)

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					send(.Completed)
				}
			}
		}
	}

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

	@final func enumerateOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				scheduler.schedule { send(event) }
				return ()
			}
		}
	}

	@final func concat(stream: Enumerable<T>) -> Enumerable<T> {
		return Enumerable { send in
			let serialDisposable = SerialDisposable()

			serialDisposable.innerDisposable = self.enumerate { event in
				switch event {
				case let .Completed:
					serialDisposable.innerDisposable = stream.enumerate(send)

				default:
					send(event)
				}
			}

			return serialDisposable
		}
	}

	@final func takeLast(count: Int) -> Enumerable<T> {
		return Enumerable { send in
			let values: Atomic<T[]> = Atomic([])

			return self.enumerate { event in
				switch event {
				case let .Next(value):
					values.modify { (var arr) in
						arr.append(value)
						while arr.count > count {
							arr.removeAtIndex(0)
						}

						return arr
					}

				case let .Completed:
					for v in values.value {
						send(.Next(Box(v)))
					}

					send(.Completed)

				default:
					send(event)
				}
			}
		}
	}

	@final func aggregate<U>(initialValue: U, _ f: (U, T) -> U) -> Enumerable<U> {
		let scanned = scan(initialValue, f)

		return Enumerable<U>.single(initialValue)
			.concat(scanned)
			.takeLast(1)
	}

	@final func collect() -> Enumerable<SequenceOf<T>> {
		return self
			.aggregate([]) { (var values, current) in
				values.append(current)
				return values
			}
			.map { SequenceOf($0) }
	}

	@final func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				switch event {
				case let .Error:
					scheduler.schedule { send(event) }

				default:
					scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) { send(event) }
				}
			}
		}
	}

	@final func deliverOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { send in
			return self.enumerate { event in
				scheduler.schedule { send(event) }
				return ()
			}
		}
	}

	/*
	@final func timeout(interval: NSTimeInterval, onScheduler: Scheduler) -> Enumerable<T>
	*/
}
