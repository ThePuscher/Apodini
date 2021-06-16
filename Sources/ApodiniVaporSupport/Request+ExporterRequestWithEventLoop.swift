//
//  Request+ExporterRequestWithEventLoop.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

import Apodini
import Vapor


extension Vapor.Request: ExporterRequestWithEventLoop {
    public var information: Set<Information> {
        Set(headers.map { name, value in
            Information(key: name, value: value)
        })
    }
}
