//
//  Disposable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

@class_protocol
protocol Disposable {
	var disposed: Bool { get }

	func dispose()
}

class SimpleDisposable: Disposable {
	var disposed = false
	
	func dispose() {
        self.disposed = true
        OSMemoryBarrier()
	}
}

class ActionDisposable: Disposable {
	var action: Atomic<(() -> ())?>
	
	var disposed: Bool {
		get {
			return self.action.value == nil
		}
	}

	init(action: () -> ()) {
		self.action = Atomic(action)
	}
	
	func dispose() {
		self.action.value?()
	}
}

class CompositeDisposable: Disposable {
	var disposables: Atomic<Disposable[]?> = Atomic([])
	
	var disposed: Bool {
		get {
			return self.disposables.value == nil
		}
	}
	
	func dispose() {
		if let ds = self.disposables.replace(nil) {
			for d in ds {
				d.dispose()
			}
		}
	}
	
	func addDisposable(d: Disposable?) {
		if d == nil {
			return
		}
	
		let shouldDispose: Bool = self.disposables.withValue {
			if var ds = $0 {
				ds.append(d!)
				return false
			} else {
				return true
			}
		}
		
		if shouldDispose {
			d!.dispose()
		}
	}
	
	func removeDisposable(d: Disposable?) {
		if d == nil {
			return
		}
	
		self.disposables.modify {
			if let ds = $0 {
				return removeObjectIdenticalTo(d!, fromArray: ds)
			} else {
				return nil
			}
		}
	}
}

class ScopedDisposable: Disposable {
	let innerDisposable: Disposable
	
	var disposed: Bool {
		get {
			return self.innerDisposable.disposed
		}
	}
	
	init(_ disposable: Disposable) {
		self.innerDisposable = disposable
	}
	
	deinit {
		self.dispose()
	}
	
	func dispose() {
		self.innerDisposable.dispose()
	}
}
