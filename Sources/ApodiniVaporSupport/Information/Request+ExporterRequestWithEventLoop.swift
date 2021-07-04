//
//  Request+ExporterRequestWithEventLoop.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

import Apodini
import Vapor
import Foundation


extension Vapor.Request: ExporterRequestWithEventLoop {
    public var information: [AnyInformation] {
        headers.map { key, rawValue in
            AnyHTTPInformation(key: key, rawValue: rawValue)
        }
    }
}

/// Provides a wrapper around the `Vapor.Request`.
/// This is specifically required and useful if the Exporter wants to dynamically
/// inject `Information` into the request.
public struct VaporRequestWrapper: ExporterRequestWithEventLoop {
    public let request: Vapor.Request
    public let information: [AnyInformation]

    public var eventLoop: EventLoop {
        request.eventLoop
    }
    public var remoteAddress: SocketAddress? {
        request.remoteAddress
    }

    public init(wrapping request: Vapor.Request, with information: [AnyInformation] = []) {
        self.request = request
        self.information = request.information + information
    }
}
