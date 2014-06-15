//
//  Atomic.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An atomic variable.
@final class Atomic<T> {
	let _lock = SpinLock()
	
	let _box: MutableBox<T>
	
	/// Atomically gets or sets the value of the variable.
	var value: T {
		get {
			return _lock.withLock {
				return self._box
			}
		}
	
		set(newValue) {
			_lock.lock()
			_box.value = newValue
			_lock.unlock()
		}
	}
	
	/// Initializes the variable with the given initial value.
	init(_ value: T) {
		_box = MutableBox(value)
	}
	
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the new value.
	func replace(newValue: T) -> T {
		return modify { oldValue in newValue }
	}
	
	/// Atomically modifies the variable.
	///
	/// Returns the new value.
	func modify(action: T -> T) -> T {
		_lock.lock()
		let newValue = action(_box)
		_box.value = newValue
		_lock.unlock()
		
		return newValue
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<U>(action: T -> U) -> U {
		_lock.lock()
		let result = action(_box)
		_lock.unlock()
		
		return result
	}

	@conversion
	func __conversion() -> T {
		return value
	}
}
