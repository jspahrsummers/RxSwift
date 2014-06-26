//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream that sends the same events to all observers.
class Observable<T>: Stream<T> {
	typealias Observer = T -> ()

	var current: T { get }
	func observe(observer: Observer) -> Disposable
	func replay(count: Int) -> Enumerable<T>

	init(initialValue: T, generator: Observer -> Disposable?)
	class func constant(value: T) -> Observable<T>
	class func interval(interval: NSTimeInterval, onScheduler: RepeatableScheduler, withLeeway: NSTimeInterval = 0) -> Signal<NSDate>

	func filter(base: T, pred: T -> Bool) -> Observable<T>
	func combineLatestWith<U>(stream: Observable<U>) -> Observable<(T, U)>
	func sampleOn<U>(sampler: Observable<U>) -> Observable<T>
}
