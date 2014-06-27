//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Stream<T> {
	func map<U>(f: T -> U) -> Stream<U> {
		assert(false)
	}

	func scan<U>(initial: U, _ f: (U, T) -> U) -> Stream<U>
	func combinePrevious<U>(initial: T, f: (T, T) -> U) -> Stream<U>
	func zipWith<U>(stream: Stream<U>) -> Stream<(T, U)>
	func mergeWith(stream: Stream<T>) -> Stream<T>
	func skipRepeats<U: Equatable, EV: TypeEquality where EV.From == T, EV.To == Stream<U>>(ev: EV) -> Stream<U>
	func delay(interval: NSTimeInterval) -> Stream<T>
	func throttle(interval: NSTimeInterval) -> Stream<T>
	func takeUntilReplacement(stream: Stream<T>) -> Stream<T>
	func switchToLatest<U, EV: TypeEquality where EV.From == T, EV.To == Stream<Stream<U>>>(ev: EV) -> Stream<U>
	func deliverOn(scheduler: Scheduler) -> Stream<T>
}
