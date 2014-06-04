//
//  Disposable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

protocol Disposable {
	func dispose()
}

class SimpleDisposable: Disposable {
	var disposed = false
	
	func dispose() {
		disposed = true
	}
}

class ActionDisposable: Disposable {
	var action: (() -> ())?

	init(action: () -> ()) {
		self.action = action
	}
	
	func dispose() {
		self.action?()
		self.action = nil
	}
}