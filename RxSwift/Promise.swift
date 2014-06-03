//
//  Promise.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class Promise<T> {
	var work: () -> T

	init(work: () -> T) {
		self.work = work;
	}
	
	func start(scheduler: Scheduler) -> Disposable? {
		return nil
	}
	
	func result() -> T {
		return self.work()
	}
	
	func whenFinished(scheduler: Scheduler, action: T -> ()) -> Disposable? {
		return nil
	}
}