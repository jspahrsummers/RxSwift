//
//  Observer.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

@class_protocol
protocol Observer {
	typealias EventType: AnyObject

	func send(Event<EventType>)
}