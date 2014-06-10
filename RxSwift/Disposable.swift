//
//  Disposable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

protocol Disposable {
	var disposed: Bool { get }

	func dispose()
}

class SimpleDisposable: Disposable {
	var disposed = false
	
	func dispose() {
        disposed = true
        OSMemoryBarrier()
	}
}

class ActionDisposable: Disposable {
	let lock = SpinLock()
	var action: (() -> ())?
	
	var disposed: Bool {
		get {
			return lock.withLock {
				return (self.action == nil)
			}
		}
	}

	init(action: () -> ()) {
		self.action = action
	}
	
	func dispose() {
		lock.lock()
		let action = self.action
		self.action = nil
		lock.unlock()
		
		action?()
	}
}
