//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Observable<T>: Stream<T> {
	typealias Observer = Event<T> -> ()
	
	let _observe: Observer -> ()
	init(_ observe: Observer -> ()) {
		self._observe = observe
	}
	
	let observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var observers: Box<Observer>[] = []
 
	func observe(observer: Observer) -> Disposable {
		let box = Box(observer)
	
		dispatch_sync(self.observerQueue, {
			self.observers.append(box)
		})
		
		self._observe(box.value)
		
		return ActionDisposable {
			dispatch_sync(self.observerQueue, {
				self.observers = removeObjectIdenticalTo(box, fromArray: self.observers)
			})
		}
	}

	func replay() -> (AsyncSequence<T>, Disposable) {
		let s = AsyncSequence<T>()
		return (s, self.observe(s.send))
	}
	
	override class func empty() -> Stream<T> {
		return Observable { send in
			send(Event.Completed)
		}
	}
	
	override class func single(T) -> Stream<T> {
		return Stream()
	}
	
	override class func never() -> Stream<T> {
		return Stream()
	}

	override func map<U: AnyObject>(transform: T -> U) -> Stream<U> {
		return .empty()
	}
	
	override func flatten<U: AnyObject>() -> Stream<U> {
		return .empty()
	}
}
