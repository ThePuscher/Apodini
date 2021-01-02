//
//  GRPCServiceUnary.swift
//  
//
//  Created by Moritz Schüll on 20.12.20.
//

import Foundation
@_implementationOnly import Vapor

// MARK: Unary request handler
extension GRPCService {
    func createUnaryHandler(requestHandler: EndpointRequestHandler<GRPCInterfaceExporter>)
    -> (Vapor.Request) -> EventLoopFuture<Vapor.Response> {
        { (request: Vapor.Request) in
            let promise = request.eventLoop.makePromise(of: Vapor.Response.self)
            request.body.collect().whenSuccess { _ in
                let response = requestHandler(request: request)
                let result = response.map { encodableAction -> Vapor.Response in
                    switch encodableAction {
                    case let .send(element),
                         let .final(element):
                        return self.makeResponse(element)
                    case .nothing, .end:
                        return self.makeResponse()
                    }
                }

                promise.completeWith(result)
            }
            return promise.futureResult
        }
    }

    /// Exposes a simple unary endpoint for the handle that the service was initialized with.
    /// The endpoint will be accessible at [host]/[serviceName]/[endpoint].
    /// - Parameters:
    ///     - endpoint: The name of the endpoint that should be exposed.
    func exposeUnaryEndpoint(name endpoint: String,
                             requestHandler: EndpointRequestHandler<GRPCInterfaceExporter>) {
        let path = [
            Vapor.PathComponent(stringLiteral: serviceName),
            Vapor.PathComponent(stringLiteral: endpoint)
        ]

        app.on(.POST, path) { request in
            self.createUnaryHandler(requestHandler: requestHandler)(request)
        }
    }
}