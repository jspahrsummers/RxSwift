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