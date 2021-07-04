//
//  HTTPHeaders+Context.swift
//  
//
//  Created by Paul Schmiedmayer on 5/26/21.
//

import Apodini
import Vapor


extension Vapor.HTTPHeaders {
    /// Creates a `Vapor``HTTPHeaders` instance based on an `Apodini` `Information` array.
    /// - Parameter information: The `Apodini` `Information` array that should be transformed in a `Vapor``HTTPHeaders` instance
    public init(_ information: InformationSet) {
        self.init()
        for (key, value) in information
            .compactMap({ $0.any() as? AnyHTTPInformation })
            .map({ ($0.key, $0.value) }) {
            self.add(name: key.header, value: value)
        }
    }
}
