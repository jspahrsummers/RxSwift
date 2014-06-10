//
//  Atomic.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Atomic<T> {
	let lock = SpinLock()
	let wrapper: ObjectWrapper<T>
	
	var value: T {
		get {
			return lock.withLock {
				return self.wrapper.value
			}
		}
	
		set(newValue) {
			lock.lock()
			self.wrapper.value = newValue
			lock.unlock()
		}
	}
	
	init(_ value: T) {
		self.wrapper = ObjectWrapper(value)
	}
	
	func replace(newValue: T) -> T {
		lock.lock()
		let oldValue = self.wrapper.value
		self.wrapper.value = newValue
		lock.unlock()
		
		return oldValue
	}
}