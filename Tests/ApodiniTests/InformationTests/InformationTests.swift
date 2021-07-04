//
//  InformationTests.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

@testable import Apodini
import ApodiniVaporSupport
import XCTApodini


final class InformationTests: XCTestCase {
    func testMockInformation() throws {
        let informationArray: [AnyInformation] = [
            MockInformation("InformationTest"),
            MockInformationWithDynamicKey(key: "key", value: "value"),
            MockIntInformation(4)
        ]

        let information2Array: [AnyInformation] = [
            MockInformationWithDynamicKey(key: MockIntInformation.key.id, value: "6")
        ]

        let information = InformationSet(informationArray)
        let information2 = InformationSet(information2Array)

        XCTAssertEqual(information[MockInformation.self], "InformationTest")
        XCTAssertRuntimeFailure(information[MockInformationWithDynamicKey.self])

        let anyValue = information[MockInformation.key] // returns Any?
        let stringValue: String? = information[MockInformation.key]
        let dynamicValue = information[DynamicStringKey(id: "key")]
        let intStringValue = information[MockIntInformation.key] // should be the raw value
        let intValue = information[MockIntInformation.self]
        let int2StringValue = information2[MockIntInformation.key]
        let int2Value = information2[MockIntInformation.self]

        XCTAssertEqual(try XCTUnwrap(anyValue as? String), "InformationTest")
        XCTAssertEqual(try XCTUnwrap(anyValue as? String), stringValue)
        XCTAssertEqual(dynamicValue, "value")
        XCTAssertEqual(intStringValue, "4")
        XCTAssertEqual(intValue, 4)
        XCTAssertEqual(int2StringValue, "6")
        XCTAssertEqual(int2Value, 6)

        let nonExistentValue = information[ObjectIdentifier(Int.self)]
        let nonExistentDynamicValue = information[DynamicStringKey(id: "asdf")]

        XCTAssert(nonExistentValue == nil)
        XCTAssert(nonExistentDynamicValue == nil)

        var illegalCast: Int?
        XCTAssertRuntimeFailure(illegalCast = information[MockInformation.key])

        XCTAssertRuntimeFailure(MockInformationWithDynamicKey.key)

        XCTAssertEqual("".information.count, 0)
    }

    func testInformationParsingAuthentication() throws {
        let basicAuthorization = try XCTUnwrap(
            AnyHTTPInformation(key: "Authorization", rawValue: "Basic UGF1bFNjaG1pZWRtYXllcjpTdXBlclNlY3JldFBhc3N3b3Jk")
                .typed(Authorization.self)
        )
        XCTAssertEqual(basicAuthorization.type, "Basic")
        XCTAssertEqual(basicAuthorization.credentials, "UGF1bFNjaG1pZWRtYXllcjpTdXBlclNlY3JldFBhc3N3b3Jk")
        XCTAssertEqual(basicAuthorization.basic?.username, "PaulSchmiedmayer")
        XCTAssertEqual(basicAuthorization.basic?.password, "SuperSecretPassword")
        XCTAssertNil(basicAuthorization.bearerToken)
        
        
        let bearerAuthorization = try XCTUnwrap(
            AnyHTTPInformation(key: "Authorization", rawValue: "Bearer QWEERTYUIOPASDFGHJKLZXCVBNM")
                .typed(Authorization.self)
        )
        
        XCTAssertEqual(bearerAuthorization.type, "Bearer")
        XCTAssertEqual(bearerAuthorization.credentials, "QWEERTYUIOPASDFGHJKLZXCVBNM")
        XCTAssertEqual(bearerAuthorization.bearerToken, "QWEERTYUIOPASDFGHJKLZXCVBNM")
        XCTAssertNil(bearerAuthorization.basic)
    }
    
    func testInformationParsingCookies() throws {
        let noCookies = try XCTUnwrap(
            AnyHTTPInformation(key: "Cookie", rawValue: "")
                .typed(Cookies.self)
        )
        XCTAssertTrue(noCookies.isEmpty)
        
        let noValidCookies = try XCTUnwrap(
            AnyHTTPInformation(key: "Cookie", rawValue: "test=")
                .typed(Cookies.self)
        )
        XCTAssertTrue(noValidCookies.isEmpty)
        
        let oneCookie = try XCTUnwrap(
            AnyHTTPInformation(key: "Cookie", rawValue: "name=value")
                .typed(Cookies.self)
        )
        XCTAssertEqual(oneCookie.count, 1)
        XCTAssertEqual(oneCookie["name"], "value")
        
        let cookies = try XCTUnwrap(
            AnyHTTPInformation(key: "Cookie", rawValue: "name=value; name2=value2; name3=value3")
                .typed(Cookies.self)
        )
        XCTAssertEqual(cookies.count, 3)
        XCTAssertEqual(cookies["name"], "value")
        XCTAssertEqual(cookies["name2"], "value2")
        XCTAssertEqual(cookies["name3"], "value3")
    }
    
    func testInformationParsingETag() throws {
        let weakETag = try XCTUnwrap(
            AnyHTTPInformation(key: "ETag", rawValue: "W/\"ABCDE\"")
                .typed(ETag.self)
        )
        XCTAssertTrue(weakETag.isWeak)
        XCTAssertEqual(weakETag.tag, "ABCDE")
        
        let eTag = try XCTUnwrap(
            AnyHTTPInformation(key: "ETag", rawValue: "\"ABCDE\"")
                .typed(ETag.self)
        )
        XCTAssertFalse(eTag.isWeak)
        XCTAssertEqual(eTag.tag, "ABCDE")
        
        
        XCTAssertNil(
            AnyHTTPInformation(key: "ETag", rawValue: "")
                .typed(ETag.self)
        )
    }
    
    func testInformationParsingExpires() throws {
        let expires = try XCTUnwrap(
            AnyHTTPInformation(key: "Expires", rawValue: "Wed, 16 June 2021 11:42:00 GMT")
                .typed(Expires.self)
        )
        XCTAssertEqual(expires.value, Date(timeIntervalSince1970: 1623843720))
        
        
        XCTAssertNil(
            AnyHTTPInformation(key: "Expires", rawValue: "...")
                .typed(Expires.self)
        )
    }
    
    func testInformationParsingRedirectTo() throws {
        let redirectTo = try XCTUnwrap(
            AnyHTTPInformation(key: "Location", rawValue: "https://ase.in.tum.de/schmiedmayer")
                .typed(RedirectTo.self)
        )
        XCTAssertEqual(redirectTo.value.absoluteString, "https://ase.in.tum.de/schmiedmayer")
    }
}
