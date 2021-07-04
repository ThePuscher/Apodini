//
//  ThrowsTests.swift
//  
//
//  Created by Max Obermeier on 22.01.21.
//


import XCTest
import XCTApodini
@testable import Apodini
import Vapor

class ThrowsTests: ApodiniTests {
    struct ErrorTestHandler: Handler {
        @Throws(.badInput, reason: "!badInput!", description: "<badInput>")
        var error1: ApodiniError
        
        @Throws(.badInput, reason: "!badInput!", information: MockInformation("testInformation"))
        var error2: ApodiniError
        
        @Throws(.badInput, description: "<badInput>")
        var error3: ApodiniError
        
        @Throws(.badInput, description: "<badInput>", AnyPropertyOption(key: .errorType, value: .other))
        var error4: ApodiniError

        var errorCode: Int = 0
        
        var applyChanges = false
        
        var reason: String?
        
        var description: String?
        
        func handle() throws -> Bool {
            switch errorCode {
            case 1:
                if applyChanges {
                    throw error1(reason: reason, description: description)
                } else {
                    throw error1
                }
            case 2:
                if applyChanges {
                    throw error2(reason: reason, description: description, options: .webSocketErrorCode(.goingAway))
                } else {
                    throw error2
                }
            case 3:
                if applyChanges {
                    throw error3(reason: reason, description: description)
                } else {
                    throw error3
                }
            case 4:
                if applyChanges {
                    throw error4(reason: reason, description: description)
                } else {
                    throw error4
                }
            default:
                return false
            }
        }
    }
    
    func testOptionMechanism() throws {
        // default
        XCTAssertEqual(.badInput, ErrorTestHandler(errorCode: 1).evaluationError().option(for: .errorType))
        // overwrite
        XCTAssertEqual(.other, ErrorTestHandler(errorCode: 4).evaluationError().option(for: .errorType))
    }
    
    func testReasonAndDescriptionPresence() throws {
        print(ErrorTestHandler(errorCode: 1).evaluationError().message(for: MockExporter<String>.self))
        XCTAssertTrue(ErrorTestHandler(errorCode: 1).evaluationError().message(for: MockExporter<String>.self).contains("!badInput!"))
        #if DEBUG
        XCTAssertTrue(ErrorTestHandler(errorCode: 1).evaluationError().message(for: MockExporter<String>.self).contains("<badInput>"))
        #else
        XCTAssertFalse(ErrorTestHandler(errorCode: 1).evaluationError().message(for: MockExporter<String>.self).contains("<badInput>"))
        #endif
        
        XCTAssertTrue(ErrorTestHandler(errorCode: 2).evaluationError().message(for: MockExporter<String>.self).contains("!badInput!"))
        XCTAssertFalse(ErrorTestHandler(errorCode: 2).evaluationError().message(for: MockExporter<String>.self).contains("<badInput>"))
        
        XCTAssertFalse(ErrorTestHandler(errorCode: 3).evaluationError().message(for: MockExporter<String>.self).contains("!badInput!"))
        #if DEBUG
        XCTAssertTrue(ErrorTestHandler(errorCode: 3).evaluationError().message(for: MockExporter<String>.self).contains("<badInput>"))
        #else
        XCTAssertFalse(ErrorTestHandler(errorCode: 3).evaluationError().message(for: MockExporter<String>.self).contains("<badInput>"))
        #endif
    }
    
    func testReasonAndDescriptionOverwrite() throws {
        XCTAssertTrue(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: "!other!",
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("!other!"))
        #if DEBUG
        XCTAssertTrue(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: "!other!",
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("<other>"))
        #else
        XCTAssertFalse(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: "!other!",
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("<other>"))
        #endif
        
        XCTAssertTrue(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: "!other!",
                        description: nil).evaluationError().message(for: MockExporter<String>.self).contains("!other!"))
        XCTAssertFalse(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: "!other!",
                        description: nil).evaluationError().message(for: MockExporter<String>.self).contains("<other>"))
        
        XCTAssertFalse(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: nil,
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("!other!"))
        #if DEBUG
        XCTAssertTrue(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: nil,
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("<other>"))
        #else
        XCTAssertFalse(ErrorTestHandler(
                        errorCode: 4,
                        applyChanges: true,
                        reason: nil,
                        description: "<other>").evaluationError().message(for: MockExporter<String>.self).contains("<other>"))
        #endif
    }

    func testInformation() throws {
        XCTAssertEqual(
            ErrorTestHandler(errorCode: 2).evaluationError().information[MockInformation.self],
            "testInformation"
        )
    }
}

extension MockExporter: StandardErrorCompliantExporter {
    public typealias ErrorMessagePrefixStrategy = StandardErrorMessagePrefix
}

private extension Handler {
    func evaluationError() -> ApodiniError {
        do {
            _ = try handle()
            XCTFail("This function expects the Handler to fail.")
            return ApodiniError(type: .other)
        } catch {
            return error.apodiniError
        }
    }
}
