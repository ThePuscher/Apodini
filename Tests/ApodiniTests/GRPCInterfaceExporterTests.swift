//
//  GRPCInterfaceExporterTests.swift
//  
//
//  Created by Moritz Schüll on 20.12.20.
//

import XCTest
@testable import Vapor
@testable import Apodini

private struct GRPCTestHandler: Handler {
    @Parameter("name",
               .gRPC(.fieldTag(1)))
    var name: String

    func handle() -> String {
        "Hello \(name)"
    }
}

private struct GRPCTestHandler2: Handler {
    @Parameter("name",
               .gRPC(.fieldTag(1)))
    var name: String
    @Parameter("age",
               .gRPC(.fieldTag(2)))
    var age: Int32

    func handle() -> String {
        "Hello \(name), you are \(age) years old."
    }
}

private struct GRPCNothingHandler: Handler {
    func handle() -> Apodini.Response<Int32> {
        .nothing
    }
}

private struct GRPCStreamTestHandler: Handler {
    @Parameter("name",
               .gRPC(.fieldTag(1)))
    var name: String

    func handle() -> Apodini.Response<String> {
        .send("Hello \(name)")
    }
}

// MARK: - Unary tests
final class GRPCInterfaceExporterTests: ApodiniTests {
    // swiftlint:disable implicitly_unwrapped_optional
    fileprivate var service: GRPCService!
    fileprivate var handler: GRPCTestHandler!
    fileprivate var endpoint: Endpoint<GRPCTestHandler>!
    fileprivate var exporter: GRPCInterfaceExporter!
    fileprivate var headers: HTTPHeaders!
    // swiftlint:enable implicitly_unwrapped_optional

    fileprivate let serviceName = "TestService"
    fileprivate let methodName = "testMethod"
    fileprivate let requestData1: [UInt8] = [0, 0, 0, 0, 10, 10, 6, 77, 111, 114, 105, 116, 122, 16, 23]
    fileprivate let requestData2: [UInt8] = [0, 0, 0, 0, 9, 10, 5, 66, 101, 114, 110, 100, 16, 65]

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = GRPCService(name: serviceName, app: app)
        handler = GRPCTestHandler()
        endpoint = handler.mockEndpoint()
        exporter = GRPCInterfaceExporter(app)
        headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/grpc+proto")
    }

    func testDefaultEndpointNaming() throws {
        let expectedServiceName = "Group1Group2Service"

        let webService = WebServiceModel()

        let handler = GRPCTestHandler()
        var endpoint = handler.mockEndpoint()

        webService.addEndpoint(&endpoint, at: ["Group1", "Group2"])

        let exporter = GRPCInterfaceExporter(app)
        exporter.export(endpoint)

        XCTAssertNotNil(exporter.services[expectedServiceName])
    }

    /// Checks that the GRPC exporter considers `.serviceName` context
    /// values for naming services.
    func testExplicitEndpointNaming() throws {
        let expectedServiceName = "MyService"

        let webService = WebServiceModel()

        let handler = GRPCTestHandler()
        let node = ContextNode()
        node.addContext(GRPCServiceNameContextKey.self, value: expectedServiceName, scope: .current)
        var endpoint = handler.mockEndpoint(context: Context(contextNode: node))

        webService.addEndpoint(&endpoint, at: ["Group1", "Group2"])

        let exporter = GRPCInterfaceExporter(app)
        exporter.export(endpoint)

        XCTAssertNotNil(exporter.services[expectedServiceName])
    }

    func testShouldAcceptMultipleEndpoints() throws {
        let context = endpoint.createConnectionContext(for: exporter)

        try service.exposeEndpoint(name: "endpointName1", context: context)
        XCTAssertNoThrow(try service.exposeEndpoint(name: "endpointName2", context: context))
        XCTAssertNoThrow(try service.exposeEndpoint(name: "endpointName3", context: context))
    }

    func testShouldNotOverwriteExistingEndpoint() throws {
        let context = endpoint.createConnectionContext(for: exporter)

        try service.exposeEndpoint(name: "endpointName", context: context)
        XCTAssertThrowsError(try service.exposeEndpoint(name: "endpointName", context: context))
        XCTAssertThrowsError(try service.exposeEndpoint(name: "endpointName", context: context))
    }

    func testShouldRequireContentTypeHeader() throws {
        let context = endpoint.createConnectionContext(for: exporter)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         version: .init(major: 2, minor: 0),
                                         headers: .init(),
                                         collectedBody: ByteBuffer(bytes: requestData1),
                                         remoteAddress: nil,
                                         logger: app.logger,
                                         on: group.next())

        var handler = service.createStreamingHandler(context: context)
        XCTAssertThrowsError(try handler(vaporRequest).wait())

        handler = service.createStreamingHandler(context: context)
        XCTAssertThrowsError(try handler(vaporRequest).wait())
    }

    func testUnaryRequestHandlerWithOneParamater() throws {
        let context = endpoint.createConnectionContext(for: exporter)

        // let expectedResponseString = "Hello Moritz"
        let expectedResponseData: [UInt8] =
            [0, 0, 0, 0, 14, 10, 12, 72, 101, 108, 108, 111, 32, 77, 111, 114, 105, 116, 122]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         version: .init(major: 2, minor: 0),
                                         headers: headers,
                                         collectedBody: ByteBuffer(bytes: requestData1),
                                         remoteAddress: nil,
                                         logger: app.logger,
                                         on: group.next())

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }

    func testUnaryRequestHandlerWithTwoParameters() throws {
        let handler = GRPCTestHandler2()
        let endpoint = handler.mockEndpoint()
        let context = endpoint.createConnectionContext(for: exporter)

        // let expectedResponseString = "Hello Moritz, you are 23 years old."
        let expectedResponseData: [UInt8] = [
            0, 0, 0, 0, 37,
            10, 35, 72, 101, 108, 108, 111, 32, 77,
            111, 114, 105, 116, 122, 44, 32, 121, 111,
            117, 32, 97, 114, 101, 32, 50, 51, 32, 121,
            101, 97, 114, 115, 32, 111, 108, 100, 46
        ]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         version: .init(major: 2, minor: 0),
                                         headers: headers,
                                         collectedBody: ByteBuffer(bytes: requestData1),
                                         remoteAddress: nil,
                                         logger: app.logger,
                                         on: group.next())

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }

    /// Tests request validation for the GRPC exporter.
    /// Should throw for a payload that does not contain data for all required parameters.
    func testUnaryRequestHandlerRequiresAllParameters() throws {
        let endpoint = GRPCTestHandler2().mockEndpoint()
        let context = endpoint.createConnectionContext(for: exporter)

        let incompleteData: [UInt8] = [0, 0, 0, 0, 8, 10, 6, 77, 111, 114, 105, 116, 122]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         version: .init(major: 2, minor: 0),
                                         headers: headers,
                                         collectedBody: ByteBuffer(bytes: incompleteData),
                                         remoteAddress: nil,
                                         logger: app.logger,
                                         on: group.next())

        let expectation = XCTestExpectation()
        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        response.body.collect(on: vaporRequest.eventLoop)
            .whenComplete { result in
                switch result {
                case .failure:
                    XCTAssert(true)
                    expectation.fulfill()
                case .success:
                    XCTFail("Expected request to fail, but it succeeded")
                    expectation.fulfill()
                }
            }
        wait(for: [expectation], timeout: 20)
    }

    /// The unary handler should only consider the first message in case
    /// it receives multiple messages in one HTTP frame.
    func testUnaryRequestHandler_2Messages_1Frame() throws {
        let context = endpoint.createConnectionContext(for: exporter)

        // First one is "Moritz", second one is "Bernd".
        // Only the first should be considered.
        let requestData: [UInt8] = [
            0, 0, 0, 0, 10, 10, 6, 77, 111, 114, 105, 116, 122, 16, 23,
            0, 0, 0, 0, 9, 10, 5, 66, 101, 114, 110, 100, 16, 23
        ]

        // let expectedResponseString = "Hello Moritz"
        let expectedResponseData: [UInt8] =
            [0, 0, 0, 0, 14, 10, 12, 72, 101, 108, 108, 111, 32, 77, 111, 114, 105, 116, 122]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         version: .init(major: 2, minor: 0),
                                         headers: headers,
                                         collectedBody: ByteBuffer(bytes: requestData),
                                         remoteAddress: nil,
                                         logger: app.logger,
                                         on: group.next())

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }
}

// MARK: - Streaming tests
extension GRPCInterfaceExporterTests {
    /// Tests the client-streaming handler for a request with
    /// 1 HTTP frame that contains 1 GRPC messages.
    func testClientStreamingHandlerWith_1Message_1Frame() throws {
        let context = endpoint.createConnectionContext(for: self.exporter)

        // let expectedResponseString = "Hello Moritz"
        let expectedResponseData: [UInt8] =
            [0, 0, 0, 0, 14, 10, 12, 72, 101, 108, 108, 111, 32, 77, 111, 114, 105, 116, 122]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         on: group.next())
        vaporRequest.headers = headers
        let stream = Vapor.Request.BodyStream(on: vaporRequest.eventLoop)
        vaporRequest.bodyStorage = .stream(stream)

        _ = stream.write(.buffer(ByteBuffer(bytes: requestData1)))
        _ = stream.write(.end)

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }

    /// Tests the client-streaming handler for a request with
    /// 1 HTTP frame that contains 2 GRPC messages.
    ///
    /// The handler should only return the response for the last (second)
    /// message contained in the frame.
    func testClientStreamingHandlerWith_2Messages_1Frame() throws {
        let service = GRPCService(name: serviceName, app: app)
        let handler = GRPCStreamTestHandler()
        let endpoint = handler.mockEndpoint()
        let context = endpoint.createConnectionContext(for: self.exporter)

        let requestData: [UInt8] = [
            0, 0, 0, 0, 10, 10, 6, 77, 111, 114, 105, 116, 122, 16, 23,
            0, 0, 0, 0, 9, 10, 5, 66, 101, 114, 110, 100, 16, 23
        ]
        // let expectedResponseString = "Hello Bernd"
        let expectedResponseData: [UInt8] =
            [0, 0, 0, 0, 13, 10, 11, 72, 101, 108, 108, 111, 32, 66, 101, 114, 110, 100]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         on: group.next())
        vaporRequest.headers = headers
        let stream = Vapor.Request.BodyStream(on: vaporRequest.eventLoop)
        vaporRequest.bodyStorage = .stream(stream)

        _ = stream.write(.buffer(ByteBuffer(bytes: requestData)))
        _ = stream.write(.end)

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }

    /// Tests the client-streaming handler for a request with
    /// 2 HTTP frames that contain 2 GRPC messages.
    /// (each message comes in its own frame)
    ///
    /// The handler should only return the response for the last (second)
    /// message contained in the frame.
    func testClientStreamingHandlerWith_2Messages_2Frames() throws {
        let service = GRPCService(name: serviceName, app: app)
        let handler = GRPCStreamTestHandler()
        let endpoint = handler.mockEndpoint()
        let context = endpoint.createConnectionContext(for: self.exporter)

        // let expectedResponseString = "Hello Bernd"
        let expectedResponseData: [UInt8] =
            [0, 0, 0, 0, 13, 10, 11, 72, 101, 108, 108, 111, 32, 66, 101, 114, 110, 100]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         on: group.next())
        vaporRequest.headers = headers
        let stream = Vapor.Request.BodyStream(on: vaporRequest.eventLoop)
        vaporRequest.bodyStorage = .stream(stream)

        // write messages individually
        _ = stream.write(.buffer(ByteBuffer(bytes: requestData1)))
        _ = stream.write(.buffer(ByteBuffer(bytes: requestData2)))
        _ = stream.write(.end)

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: expectedResponseData))
    }

    /// Checks whether the returned response for a `.nothing` is indeed empty.
    func testClientStreamingHandlerNothingResponse() throws {
        let handler = GRPCNothingHandler()
        let endpoint = handler.mockEndpoint()
        let context = endpoint.createConnectionContext(for: self.exporter)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         on: group.next())
        vaporRequest.headers = headers
        let stream = Vapor.Request.BodyStream(on: vaporRequest.eventLoop)
        vaporRequest.bodyStorage = .stream(stream)

        _ = stream.write(.buffer(ByteBuffer(bytes: requestData1)))
        _ = stream.write(.end)

        let response = try service.createStreamingHandler(context: context)(vaporRequest).wait()
        let responseData = try XCTUnwrap(try response.body.collect(on: vaporRequest.eventLoop).wait())
        XCTAssertEqual(responseData, ByteBuffer(bytes: []))
    }

    private func assertServiceStream(from serviceStream: EventLoopFuture<Vapor.Response>,
                                     equals expectedFrameData: [UInt8],
                                     on eventLoop: EventLoop,
                                     fulfilling expectation: XCTestExpectation) {
        serviceStream.whenSuccess { result in
            let body = result.body.collect(on: eventLoop)
            body.whenSuccess { buffer in
                XCTAssertEqual(buffer, ByteBuffer(bytes: expectedFrameData))
                expectation.fulfill()
            }
            body.whenFailure { error in
                XCTFail("\(error)")
                expectation.fulfill()
            }
        }
        serviceStream.whenFailure { error in
            XCTFail("\(error)")
            expectation.fulfill()
        }
    }

    func testBidirectionalStreamingHandler() throws {
        let service = GRPCService(name: serviceName, app: app)
        let handler = GRPCStreamTestHandler()
        let endpoint = handler.mockEndpoint()
        let context = endpoint.createConnectionContext(for: self.exporter)

        // let expectedResponseString = "Hello Moritz"
        var expectedResponseFrame1: [UInt8] =
            [0, 0, 0, 0, 14, 10, 12, 72, 101, 108, 108, 111, 32, 77, 111, 114, 105, 116, 122]
        // let expectedResponseString = "Hello Bernd"
        let expectedResponseFrame2: [UInt8] =
            [0, 0, 0, 0, 13, 10, 11, 72, 101, 108, 108, 111, 32, 66, 101, 114, 110, 100]

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let vaporRequest = Vapor.Request(application: app.vapor.app,
                                         method: .POST,
                                         url: URI(path: "https://localhost:8080/\(serviceName)/\(methodName)"),
                                         on: group.next())
        vaporRequest.headers = headers
        let stream = Vapor.Request.BodyStream(on: vaporRequest.eventLoop)
        vaporRequest.bodyStorage = .stream(stream)

        _ = stream.write(.buffer(ByteBuffer(bytes: requestData1)))
        _ = stream.write(.buffer(ByteBuffer(bytes: requestData2)))
        _ = stream.write(.end)

        let expectation = XCTestExpectation()
        expectedResponseFrame1.append(contentsOf: expectedResponseFrame2)
        let serviceStream = service.createStreamingHandler(context: context, serviceStreaming: true)(vaporRequest)
        // Currently, I am not aware of any way to read the response frame by frame on the client side.
        // Thus, this approach just collects all frames from the stream into one buffer.
        assertServiceStream(from: serviceStream,
                            equals: expectedResponseFrame1,
                            on: group.next(),
                            fulfilling: expectation)

        wait(for: [expectation], timeout: 20)
    }
}

// MARK: - Utility tests
extension GRPCInterfaceExporterTests {
    func testServiceNameUtility_DefaultName() {
        let webService = WebServiceModel()
        webService.addEndpoint(&endpoint, at: ["Group1", "Group2"])

        XCTAssertEqual(gRPCServiceName(from: endpoint), "Group1Group2Service")
    }

    func testServiceNameUtility_CustomName() {
        let serviceName = "TestService"

        let node = ContextNode()
        node.addContext(GRPCServiceNameContextKey.self, value: serviceName, scope: .current)
        endpoint = handler.mockEndpoint(context: Context(contextNode: node))

        XCTAssertEqual(gRPCServiceName(from: endpoint), serviceName)
    }

    func testMethodNameUtility_DefaultName() {
        XCTAssertEqual(gRPCMethodName(from: endpoint), "grpctesthandler")
    }

    func testMethodNameUtility_CustomName() {
        let methodName = "testMethod"

        let node = ContextNode()
        node.addContext(GRPCMethodNameContextKey.self, value: methodName, scope: .current)
        endpoint = handler.mockEndpoint(context: Context(contextNode: node))

        XCTAssertEqual(gRPCMethodName(from: endpoint), methodName)
    }
}
