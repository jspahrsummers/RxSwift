//
//  Atomic.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

struct Atomic<T> {
	var lock = SpinLock()
	var wrapper: ObjectWrapper<T>
	
	init(_ value: T) {
		self.wrapper = ObjectWrapper(value)
	}
	
	mutating func replace(newValue: T) -> T {
		lock.lock()
		let oldValue = self.wrapper.value()
		self.wrapper.set(newValue)
		lock.unlock()
		
		return oldValue
	}
	
	mutating func modify(action: T -> T) -> T {
		lock.lock()
		let newValue = action(self.wrapper.value())
		self.wrapper.set(newValue)
		lock.unlock()
		
		return newValue
	}
	
	mutating func withValue<U>(action: T -> U) -> U {
		lock.lock()
		let result = action(self.wrapper.value())
		lock.unlock()
		
		return result
	}
}
