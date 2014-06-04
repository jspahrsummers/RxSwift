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
	var observers: Observer[] = []
 
	func addObserver(observer: Observer) {
		dispatch_sync(observerQueue, {
			self.observers.append(observer)
		})
		
		self.create(observer)
	}
	
	func removeObserver(observer: Observer) {
		dispatch_sync(observerQueue, {
			self.observers = self.observers.filter({
				$0 === observer
			})
		})
	}
}