//
//	ObjectWrapper.swift
//	RxSwift
//
//	Created by Justin Spahr-Summers on 2014-06-10.
//	Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

struct ObjectWrapper<T> {
	let backingVar: T[]
	
	func value() -> T {
		return backingVar[0]
	}
  
	mutating func set(newValue: T) {
		backingVar[0] = newValue
	}
	
	init(_ value: T) {
		self.backingVar = [value]
	}
}
