//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

protocol Scheduler {
	func schedule(work: () -> ()) -> Disposable?
}

class ImmediateScheduler: Scheduler {
	func schedule(work: () -> ()) -> Disposable? {
		work()
		return nil
	}
}