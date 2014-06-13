//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

operator infix |> { associativity left }

class Stream<T> {
	class func empty() -> Stream<T> {
		return Stream()
	}
	
	class func single(T) -> Stream<T> {
		return Stream()
	}

	func flattenScan<S, U>(initial: S, f: (S, T) -> (S?, Stream<U>)) -> Stream<U> {
		return .empty()
	}

	@final func map<U>(f: T -> U) -> Stream<U> {
		return flattenScan(0) { (_, x) in (0, .single(f(x))) }
	}

	@final func filter(pred: T -> Bool) -> Stream<T> {
		return map { x in pred(x) ? .single(x) : .empty() }
			|> flatten
	}

	@final func take(count: Int) -> Stream<T> {
		if (count == 0) {
			return .empty()
		}

		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .single(x))
			} else {
				return (nil, .empty())
			}
		}
	}

	@final func skip(count: Int) -> Stream<T> {
		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .empty())
			} else {
				return (count, .single(x))
			}
		}
	}
}
 
@infix func |><T>(stream: Stream<Stream<T>>, f: Stream<Stream<T>> -> Stream<T>) -> Stream<T> {
	return f(stream)
}

func flatten<T>(stream: Stream<Stream<T>>) -> Stream<T> {
	return stream.flattenScan(0) { (_, s) in (0, s) }
}
