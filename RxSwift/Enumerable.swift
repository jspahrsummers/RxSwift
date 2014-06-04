//
//  Enumerable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Enumerable<T>: Stream<T> {
	typealias EventType = T
	
	let create: () -> Enumerator
	
	init(create: () -> Enumerator) {
		self.create = create
	}
	
	func newEnumerator() -> Enumerator {
		return self.create()
	}
	
	func enumerate(scheduler: Scheduler, observer: Observer) {
		// TODO
	}
}