//
//  AsyncSequence.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-12.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A consumer-driven (pull-based) stream of values.
class AsyncSequence<T>: Stream<T>, Sequence {
	typealias GeneratorType = GeneratorOf<Promise<Event<T>>>

	let _generate: () -> GeneratorType
	init(_ generate: () -> GeneratorType) {
		self._generate = generate
	}

	/// Instantiates a generator that will instantly return Promise<Event<T>>
	/// objects, representing future events in the stream.
	///
	/// Work will only begin when the generated promises are actually resolved.
	/// Each promise may be evaluated in any order, or even skipped entirely.
	func generate() -> GeneratorType {
		return self._generate()
	}
	
	override class func empty() -> AsyncSequence<T> {
		return AsyncSequence {
			return GeneratorOf { nil }
		}
	}

	override class func single(x: T) -> AsyncSequence<T> {
		return AsyncSequence {
			return SequenceOf([
				Promise { Event.Next(Box(x)) },
				Promise { Event.Completed }
			]).generate()
		}
	}

	struct _FlattenScanGenerator<S, U>: Generator {
		let disposable: Disposable
		let scanFunc: (S, T) -> (S?, Stream<U>)
		
		// TODO: Thread safety
		var valueGenerators: GeneratorOf<Promise<Event<U>>>[]
		var state: S
		var selfGenerator: GeneratorType

		mutating func generateStreamFromValue(x: T) {
			let (newState, stream) = scanFunc(state, x)

			if let s = newState {
				state = s
			} else {
				disposable.dispose()
			}

			let seq = stream as AsyncSequence<U>
			valueGenerators.append(seq.generate())
		}

		mutating func next() -> Promise<Event<U>>? {
			if disposable.disposed {
				return nil
			}

			var next = valueGenerators[0].next()
			while next == nil {
				valueGenerators.removeAtIndex(0)
				if valueGenerators.isEmpty {
					if let promise = selfGenerator.next() {
						return promise.then { event in
							switch event {
							case let .Next(x):
								self.generateStreamFromValue(x)
								return Promise { .Completed }

							case let .Completed:
								return Promise { .Completed }

							case let .Error(error):
								self.disposable.dispose()
								return Promise { .Error(error) }
							}
						}
					} else {
						return nil
					}
				}

				next = valueGenerators[0].next()
			}

			return next
		}
	}

	override func flattenScan<S, U>(initial: S, f: (S, T) -> (S?, Stream<U>)) -> AsyncSequence<U> {
		return AsyncSequence<U> {
			let g = _FlattenScanGenerator(disposable: SimpleDisposable(), scanFunc: f, valueGenerators: [], state: initial, selfGenerator: self.generate())
			return GeneratorOf(g)
		}
	}
}
