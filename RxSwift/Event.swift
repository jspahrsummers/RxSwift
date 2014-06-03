//
//  Event.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

enum Event<T: AnyObject> {
	case Next(T)
	case Error(NSError)
	case Completed
}