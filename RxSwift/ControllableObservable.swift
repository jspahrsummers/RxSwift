//
//  ControllableObservable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An Observable that can be manually controlled.
@final class ControllableObservable<T, S: Scheduler>: Observable<T, S> {
	init() {
		super.init({ _ in Promise(nil) })
	}

	func send(event: Event<T>) -> Promise<(), S> {
		var p = Promise<(), S>(())

		// TODO: Make sure this isn't silly.
		for sendBox in _observers {
			p = p.then { sendBox.value(event) }
		}

		return p
	}
}
