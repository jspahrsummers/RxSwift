//
//	ObjectWrapper.swift
//	RxSwift
//
//	Created by Justin Spahr-Summers on 2014-06-10.
//	Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class ObjectWrapper<T> {
	let backingVar: T[]
	
	var value: T {
		get {
			return backingVar[0]
		}
	
		set(newValue) {
			backingVar[0] = newValue
		}
	}

	init(_ value: T) {
		self.backingVar = [value]
	}
}
