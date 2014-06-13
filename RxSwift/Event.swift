//
//  Event.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

enum Event<T> {
	case Next(Box<T>)
	case Error(NSError)
	case Completed
	
	var isTerminating: Bool {
		get {
			switch self {
			case let .Next:
				return false
			
			default:
				return true
			}
		}
	}
	
	func map<U>(f: T -> U) -> Event<U> {
		switch self {
		case let .Next(box):
			return .Next(Box(f(box)))
			
		case let .Error(error):
			return .Error(error)
			
		case let .Completed:
			return .Completed
		}
	}
}