//
//  ObservableProperty.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a mutable property of type T along with the changes to its value.
@final class ObservableProperty<T>: Observable<T> {
	let _multicastObserver: Observer

	override var current: T {
		get {
			return super.current
		}

		set(newValue) {
			_multicastObserver(newValue)
		}
	}

	init(_ value: T) {
		super.init(initialValue: value) { observer in
			self._multicastObserver = observer
			return nil
		}
	}

	@conversion func __conversion() -> T {
		return current
	}
}
