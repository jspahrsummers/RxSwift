//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Stream<T: AnyObject> {
	class func empty() -> Stream<T> {
		return Stream()
	}

	func map<U: AnyObject>(transform: T -> U) -> Stream<U> {
		return .empty()
	}
}