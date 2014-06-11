//
//  SpinLock.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

struct SpinLock {
	var spinlock = OS_SPINLOCK_INIT
	
	mutating func lock() {
		withUnsafePointer(&spinlock, OSSpinLockLock)
	}
	
	mutating func unlock() {
		withUnsafePointer(&spinlock, OSSpinLockUnlock)
	}
	
	mutating func withLock<T>(action: () -> T) -> T {
		withUnsafePointer(&spinlock, OSSpinLockLock)
		let result = action()
		withUnsafePointer(&spinlock, OSSpinLockUnlock)
		
		return result
	}
	
	mutating func tryLock<T>(action: () -> T) -> T? {
		if !withUnsafePointer(&spinlock, OSSpinLockTry) {
			return nil
		}
		
		let result = action()
		withUnsafePointer(&spinlock, OSSpinLockUnlock)
		
		return result
	}
}
