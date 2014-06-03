//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

protocol Observer {
	typealias EventType: AnyObject

	func send(event: Event<EventType>)
}

protocol Observable {
	func addObserver<O: Observer>(observer: O)
	func removeObserver<O: Observer>(observer: O)
}

class SimpleObservable<T: AnyObject> : Observable {
	typealias EventType = T

	var observers: Observer[]
	
	init() {
		observers = []
	}

	func send(event: Event<T>) {
		for o: Observer in observers {
			o.send(event)
		}
	}
	
	func addObserver<O: Observer>(observer: O) {
	}
	
	func removeObserver<O: Observer>(observer: O) {
	}
}