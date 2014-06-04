//
//  Enumerator.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

@class_protocol
protocol Enumerator {
	typealias EventType: AnyObject

	func nextDeferredEvent(Promise<Event<EventType>>)
}