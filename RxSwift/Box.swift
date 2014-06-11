//
//  Box.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Box<T> {
	let _closure: () -> T

	var value: T {
		get {
			return self._closure()
		}
	}
	
	init(_ value: T) {
		self._closure = { value }
	}
	
	@conversion
	func __conversion() -> T {
		return self.value
	}
}

class MutableBox<T>: Box<T> {
	var _mutableClosure: () -> T

	override var value: T {
		get {
			return self._mutableClosure()
		}
	
		set(newValue) {
			self._mutableClosure = { newValue }
		}
	}
	
	init(_ value: T) {
		self._mutableClosure = { value }
		super.init(value)
	}
}