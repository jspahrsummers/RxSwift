//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Observable<T>: Stream<T> {
	typealias EventType = T
	
	let create: Observer -> ()
	init(create: Observer -> ()) {
		self.create = create
	}
	
	let observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var observers: MutableBox<Observer>[] = []
 
	func observe(observer: Observer) -> Disposable {
		let box = MutableBox(observer)
	
		dispatch_sync(self.observerQueue, {
			self.observers.append(box)
		})
		
		self.create(box)
		
		return ActionDisposable {
			dispatch_sync(self.observerQueue, {
				self.observers = removeObjectIdenticalTo(box, fromArray: self.observers)
			})
		}
	}

	func replay() -> (AsyncSequence<T>, Disposable) {
		let s = AsyncSequence<T>()
		return (s, observe(s))
	}
}
