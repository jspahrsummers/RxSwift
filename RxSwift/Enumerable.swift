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

	func enumerate(enumerator: Enumerator) -> Disposable
	func first() -> Event<T>
	func waitUntilCompleted() -> Event<()>

	init(_ enumerate: Enumerator -> Disposable?)
	class func empty() -> Enumerable<T>
	class func single(value: T) -> Enumerable<T>
	class func error(error: NSError?) -> Enumerable<T>
	class func never() -> Enumerable<T>

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
	func ignoreValues() -> Enumerable<T>
	func doEvent(action: Event<T> -> ()) -> Enumerable<T>
	func doDisposed(action: () -> ()) -> Enumerable<T>
	func collect() -> Enumerable<SequenceOf<T>>
	func timeout(interval: NSTimeInterval, onScheduler: Scheduler) -> Enumerable<T>
	func enumerateOn(scheduler: Scheduler) -> Enumerable<T>
}
