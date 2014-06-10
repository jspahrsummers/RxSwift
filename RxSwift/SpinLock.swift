//
//  SpinLock.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class SpinLock {
	var spinlock = OS_SPINLOCK_INIT
	
	func withLock<T>(action: () -> T) -> T {
		withUnsafePointer(&spinlock, OSSpinLockLock)
		let result = action()
		withUnsafePointer(&spinlock, OSSpinLockUnlock)
		
		return result
	}
	
	func tryLock<T>(action: () -> T) -> T? {
		if !withUnsafePointer(&spinlock, OSSpinLockTry) {
			return nil
		}
		
		let result = action()
		withUnsafePointer(&spinlock, OSSpinLockUnlock)
		
		return result
	}
}