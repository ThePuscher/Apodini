//
// Created by Andreas Bauer on 25.12.20.
//

#if DEBUG || RELEASE_TESTING
import XCTest
import Foundation
@testable import Apodini
import ApodiniExtension


/// A namespace for methods that generate `ValidatedRequest`s from mock data.
public enum MockRequest {
    /// Create a request on an `EmptyHandler`
    public static func createRequest(
        running eventLoop: EventLoop,
        queuedParameters parameterValues: Any??...
    ) -> DefaultValueStore.DefaultInsertingRequest {
        createRequest(on: EmptyHandler(), running: eventLoop, queuedParameters: parameterValues)
    }

    /// Create a request on `handler`
    public static func createRequest<H: Handler>(
        on handler: H,
        running eventLoop: EventLoop,
        queuedParameters parameterValues: Any??...
    ) -> DefaultValueStore.DefaultInsertingRequest {
        createRequest(on: handler, running: eventLoop, queuedParameters: parameterValues)
    }

    private static func createRequest<H: Handler>(
        on handler: H,
        running eventLoop: EventLoop,
        queuedParameters parameterValues: [Any??]
    ) -> DefaultValueStore.DefaultInsertingRequest {
        let exporter = MockExporter<String>(queued: parameterValues)
        
        let endpoint = handler.mockEndpoint()
        
        let strategy = InterfaceExporterLegacyStrategy(exporter).applied(to: endpoint)
        
        return strategy
            .decodeRequest(from: "Undefined Exporter Request", with: DefaultRequestBasis(), with: eventLoop)
            .insertDefaults(with: endpoint[DefaultValueStore.self])
    }
}
#endif
