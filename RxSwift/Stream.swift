//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Stream<T> {
	/*
	 * REQUIRED PRIMITIVES
	 */

	class func unit(value: T) -> Stream<T> {
		assert(false)
		return Stream()
	}

	func mapAccumulate<S, U>(initialState: S, _ f: (S, T) -> (S?, U)) -> Stream<U> {
		assert(false)
		return Stream<U>()
	}

	func removeNil<U>(evidence: Stream<T> -> Stream<U?>, initialValue: U) -> Stream<U> {
		assert(false)
		return Stream<U>()
	}

	func merge<U>(evidence: Stream<T> -> Stream<Stream<U>>) -> Stream<U> {
		assert(false)
		return Stream<U>()
	}

	func switchToLatest<U>(evidence: Stream<T> -> Stream<Stream<U>>) -> Stream<U> {
		assert(false)
		return Stream<U>()
	}

	/*
	 * EXTENDED OPERATORS
	 */

	func map<U>(f: T -> U) -> Stream<U> {
		return mapAccumulate(nil) { (_, value) in
			return (nil, f(value))
		}
	}

	func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Stream<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	func filter(pred: T -> Bool) -> Stream<T?> {
		return map { value in (pred(value) ? value : nil) }
	}

	/*
	@final func combinePrevious<U>(initial: T, f: (T, T) -> U) -> Stream<U> {
		let initialTuple: (T, U?) = (initial, nil)

		return self
			.scan(initialTuple) { (tuple, next) in
				let value = f(tuple.0, next)
				return (next, value)
			}
			.map { tuple in tuple.1! }
	}
	*/

	/*
	func zipWith<U>(stream: Stream<U>) -> Stream<(T, U)>
	func mergeWith(stream: Stream<T>) -> Stream<T>
	func skipRepeats<U: Equatable>(evidence: Stream<T> -> Stream<U>) -> Stream<U>
	func delay(interval: NSTimeInterval) -> Stream<T>
	func throttle(interval: NSTimeInterval) -> Stream<T>
	func takeUntilReplacement(stream: Stream<T>) -> Stream<T>
	func deliverOn(scheduler: Scheduler) -> Stream<T>
	*/
}
