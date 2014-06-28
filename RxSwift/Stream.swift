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
		return mapAccumulate(()) { (_, value) in
			return ((), f(value))
		}
	}

	func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Stream<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	func take(count: Int) -> Stream<T> {
		return mapAccumulate(0) { (n, value) in
			let newN: Int? = (n + 1 < count ? n + 1 : nil)
			return (newN, value)
		}
	}

	func combinePrevious(initialValue: T) -> Stream<(T, T)> {
		return mapAccumulate(initialValue) { (previous, current) in
			return (current, (previous, current))
		}
	}

	func skipAsNil(count: Int) -> Stream<T?> {
		return mapAccumulate(0) { (n, value) in
			if n >= count {
				return (count, value)
			} else {
				return (n + 1, nil)
			}
		}
	}

	func skipAsNilWhile(pred: T -> Bool) -> Stream<T?> {
		return mapAccumulate(true) { (skipping, value) in
			if !skipping || !pred(value) {
				return (false, value)
			} else {
				return (true, nil)
			}
		}
	}

	/*
	func zipWith<U>(stream: Stream<U>) -> Stream<(T, U)>
	func mergeWith(stream: Stream<T>) -> Stream<T>
	func delay(interval: NSTimeInterval) -> Stream<T>
	func throttle(interval: NSTimeInterval) -> Stream<T>
	func takeUntilReplacement(stream: Stream<T>) -> Stream<T>
	func deliverOn(scheduler: Scheduler) -> Stream<T>
	*/
}
