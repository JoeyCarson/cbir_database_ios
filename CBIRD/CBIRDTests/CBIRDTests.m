//
//  CBIRDTests.m
//  CBIRDTests
//
//  Created by Joseph Carson on 9/29/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//
//  See https://www.objc.io/issues/15-testing/xctest/ for some great tips and tricks
//  for using XCTest.
//

#import <XCTest/XCTest.h>
#import <CBIRDatabase/CBIRDatabase.h>

@interface CBIRDTests : XCTestCase

@end

@implementation CBIRDTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
