//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// TODO: This lives outside of the definition below because of an infinite loop
// in the compiler. Move it back within Observable once that's fixed.
struct _ZipState<T> {
	var values: T[] = []
	var completed = false

	init() {
	}

	init(_ values: T[], _ completed: Bool) {
		self.values = values
		self.completed = completed
	}
}

/// A producer-driven (push-based) stream of values that will be delivered on
/// a scheduler of type S.
class Observable<T, S: Scheduler>: Stream<T> {
	/// The type of a consumer for the stream's events.
	typealias Observer = Event<T> -> Promise<(), S>
	
	let _observe: Observer -> Promise<Disposable?, S>
	init(_ observe: Observer -> Promise<Disposable?, S>) {
		self._observe = observe
	}
	
	let _observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var _observers: Box<Observer>[] = []
 
	/// Returns a promise that will begin observing the stream for events.
	func observe(observer: Observer) -> Promise<Disposable, S> {
		let disposable = CompositeDisposable()

		let observerPromise = Promise<Observer, S> {
			let box = Box(observer)
		
			dispatch_sync(self._observerQueue, {
				self._observers.append(box)
			})
			
			disposable.addDisposable(ActionDisposable {
				dispatch_sync(self._observerQueue, {
					self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
				})
			})

			return box.value
		}

		return observerPromise
			| self._observe
			| { d -> Disposable in
				disposable.addDisposable(d)
				return disposable
			}
	}

	/// Begins observing the stream for new events on the given scheduler.
	///
	/// Returns a disposable which can be used to cease observation.
	func observeOn(scheduler: S, observer: Observer) -> Disposable {
		let disposable = SerialDisposable()

		observe(observer)
			.map { disposable.innerDisposable = $0 }
			.startOn(scheduler)

		return disposable
	}

	/// Takes events from the receiver until `trigger` sends a Next or Completed
	/// event.
	func takeUntil<U>(trigger: Observable<U, S>) -> Observable<T, S> {
		return Observable { send in
			return
				|-trigger.observe { event in
					switch event {
					case let .Error:
						return Promise(())

					default:
						return send(.Completed)
					}
				}
				| { triggerDisposable in
					return self.observe(send)
						| { selfDisposable in CompositeDisposable([triggerDisposable, selfDisposable]) }
				}
		}
	}

	/// Sends the latest value from the receiver only when `sampler` sends
	/// a value.
	///
	/// The returned observable could repeat values if `sampler` fires more
	/// often than the receiver. Values from `sampler` are ignored before the
	/// receiver sends its first value.
	func sample<U>(sampler: Observable<U, S>) -> Observable<T, S> {
		return Observable { send in
			let latest: Atomic<T?> = Atomic(nil)

			return
				|-self.observe { event in
					switch event {
					case let .Next(value):
						latest.value = value
						return Promise(())

					default:
						return send(event)
					}
				}
				| { selfDisposable in
						|-sampler.observe { event in
							switch event {
							case let .Next:
								if let v = latest.value {
									return send(.Next(Box(v)))
								} else {
									fallthrough
								}

							default:
								return Promise(())
							}
						}
						| { samplerDisposable in CompositeDisposable([selfDisposable, samplerDisposable]) }
				}
		}
	}
	
	override class func empty() -> Observable<T, S> {
		return Observable { send in
			|-send(.Completed)
			| nil
		}
	}
	
	override class func single(x: T) -> Observable<T, S> {
		return Observable { send in
			|-send(Event.Next(Box(x)))
			| send(Event.Completed)
			| nil
		}
	}

	override class func error(error: NSError) -> Observable<T, S> {
		return Observable { send in
			|-send(.Error(error))
			| nil
		}
	}

	override func flattenScan<ST, U>(initial: ST, _ f: (ST, T) -> (ST?, Stream<U>)) -> Observable<U, S> {
		return Observable<U, S> { send in
			// TODO: Thread safety
			var state = initial

			let inFlight = Atomic(1)
			let disposable = CompositeDisposable()

			let selfDisposable = SerialDisposable()
			disposable.addDisposable(selfDisposable)

			func decrementInFlight() -> Promise<(), S> {
				let p = Promise<Int, S> {
					return inFlight.modify { $0 - 1 }
				}

				return p.then { orig in
					if orig == 1 {
						return send(.Completed)
					} else {
						return Promise(())
					}
				}
			}

			let selfObserve = self.observe { event in
				switch event {
				case let .Next(value):
					let (newState, stream) = f(state, value)

					if let s = newState {
						state = s
					} else {
						selfDisposable.dispose()
					}

					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					let p = (stream as Observable<U, S>).observe { event in
						if event.isTerminating {
							disposable.removeDisposable(streamDisposable)
						}

						switch event {
						case let .Completed:
							return decrementInFlight()

						default:
							return send(event)
						}
					}

					return p.map { streamDisposable.innerDisposable = $0 }

				case let .Error(error):
					return send(.Error(error))

				case let .Completed:
					return decrementInFlight()
				}
			}

			return selfObserve.map { d in
				selfDisposable.innerDisposable = d
				return disposable
			}
		}
	}

	override func concat(stream: Stream<T>) -> Observable<T, S> {
		return Observable { send in
			let disposable = SerialDisposable()

			let selfObserve = self.observe { event in
				switch event {
				case let .Completed:
					let p = (stream as Observable<T, S>).observe(send)
					return p.map { disposable.innerDisposable = $0 }

				default:
					return send(event)
				}
			}

			return selfObserve.map { d in
				disposable.innerDisposable = d
				return disposable
			}
		}
	}

	override func zipWith<U>(stream: Stream<U>) -> Observable<(T, U), S> {
		return Observable<(T, U), S> { send in
			let states = Atomic((_ZipState<T>(), _ZipState<U>()))

			func drain() -> Promise<(), S> {
				var p = Promise<(), S>(())

				states.modify { (a, b) in
					var av = a.values
					var bv = b.values

					while !av.isEmpty && !bv.isEmpty {
						let v = (av[0], bv[0])
						av.removeAtIndex(0)
						bv.removeAtIndex(0)

						p = p.then { send(.Next(Box(v))) }
					}

					if a.completed || b.completed {
						p = p.then { send(.Completed) }
					}

					return (_ZipState(av, a.completed), _ZipState(bv, b.completed))
				}

				return p
			}

			func modifyA(f: _ZipState<T> -> _ZipState<T>) -> Promise<(), S> {
				states.modify { (a, b) in
					var newA = f(a)
					return (newA, b)
				}

				return drain()
			}

			func modifyB(f: _ZipState<U> -> _ZipState<U>) -> Promise<(), S> {
				states.modify { (a, b) in
					var newB = f(b)
					return (a, newB)
				}

				return drain()
			}

			let selfObserve = self.observe { event in
				switch event {
				case let .Next(value):
					return modifyA { s in
						var values = s.values
						values.append(value)

						return _ZipState(values, false)
					}

				case let .Error(error):
					return send(.Error(error))

				case let .Completed:
					return modifyA { s in _ZipState(s.values, true) }
				}
			}

			let otherObserve = (stream as Observable<U, S>).observe { event in
				switch event {
				case let .Next(value):
					return modifyB { s in
						var values = s.values
						values.append(value)

						return _ZipState(values, false)
					}

				case let .Error(error):
					return send(.Error(error))

				case let .Completed:
					return modifyB { s in _ZipState(s.values, true) }
				}
			}

			return selfObserve
				.then { selfDisposable in
					return otherObserve.map { otherDisposable in
						return CompositeDisposable([selfDisposable, otherDisposable])
					}
				}
		}
	}

	override func materialize() -> Observable<Event<T>, S> {
		return Observable<Event<T>, S> { send in
			return self
				.observe { event in
					var p = send(.Next(Box(event)))

					if event.isTerminating {
						p = p.then { send(.Completed) }
					}

					return p
				}
				.map { d in d }
		}
	}
}
