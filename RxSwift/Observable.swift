//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Observable<T: AnyObject, O: Observer>: Stream<T> {
	typealias EventType = AnyObject
	
	var observers: O[]
	
	init() {
		observers = []
	}

	func addObserver(observer: O) {
		observers += observer
	}
	
	func removeObserver(observer: O) {
		observers = observers.filter({
			observer == $0
		})
	}
}