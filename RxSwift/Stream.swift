//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Stream<T> {
	class func empty() -> Stream<T> {
		return Stream()
	}
	
	class func single(T) -> Stream<T> {
		return Stream()
	}
	
	class func never() -> Stream<T> {
		return Stream()
	}

	func map<U: AnyObject>(transform: T -> U) -> Stream<U> {
		return .empty()
	}
	
	func flatten<U: AnyObject>() -> Stream<U> {
		return .empty()
	}
}