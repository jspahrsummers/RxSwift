//
//  PromiseSpec.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Quick
import Nimble
import RxSwift

class PromiseSpec: QuickSpec {
    override func spec() {
        var promise: Promise<Int>!
        
        beforeEach {
            promise = Promise {
                return 5
            }
        }
        it("should block and return a result") {
            expect(promise.result()).to.equal(5)
        }
	}
}