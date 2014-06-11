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
	
	let box: MutableBox<T>
	var value: T {
		get {
			return lock.withLock {
				return self.box
			}
		}
	
		set(newValue) {
			lock.lock()
			self.box.value = newValue
			lock.unlock()
		}
	}
	
	init(_ value: T) {
		self.box = MutableBox(value)
	}
	
	func replace(newValue: T) -> T {
		return modify { oldValue in newValue }
	}
	
	func modify(action: T -> T) -> T {
		lock.lock()
		let newValue = action(self.box)
		self.box.value = newValue
		lock.unlock()
		
		return newValue
	}
	
	func withValue<U>(action: T -> U) -> U {
		lock.lock()
		let result = action(self.box)
		lock.unlock()
		
		return result
	}

	@conversion
	func __conversion() -> T {
		return self.value
	}
}
