//
// Created by Andreas Bauer on 03.07.21.
//

import Apodini

/// The `DynamicInformationKey` identifying any `AnyHTTPInformation` instances.
public struct HTTPInformationKey: DynamicInformationKey {
    public typealias Value = String

    public var header: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(Self.self))
        hasher.combine(header)
    }

    public static func == (lhs: HTTPInformationKey, rhs: HTTPInformationKey) -> Bool {
        lhs.header == rhs.header
    }
}
