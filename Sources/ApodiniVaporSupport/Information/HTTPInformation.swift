//
// Created by Andreas Bauer on 03.07.21.
//

import Apodini

/// Denotes some unspecified `HTTPInformation` implementation.
public protocol SomeHTTPInformation: AnyInformation {
    /// The HTTP header type. Must to adhere to the according standard.
    static var header: String { get }

    /// The raw HTTP header value, interpreted as a string.
    var rawValue: String { get }
}

extension SomeHTTPInformation {
    /// Makes the static `SomeHTTPInformation.header` property accessible via an instance property.
    var header: String {
        Self.header
    }
}

/// A `HTTPInformation` is a `DynamicInformationInstantiatable` for the `AnyHTTPInformation` `Information`.
/// It is used to provide implementations for individual HTTP Header types.
/// Currently the following Headers are supported as Information out of the box:
/// - `Authorization`
/// - `Cookies`
/// - `ETag`
/// - `Expires`
/// - `RedirectTo`
public protocol HTTPInformation: DynamicInformationInstantiatable, SomeHTTPInformation {
    typealias DynamicInformation = AnyHTTPInformation
}

public extension HTTPInformation {
    /// Default implementation automatically creating `InformationKey` using the
    /// `SomeHTTPInformation.header` property
    static var key: HTTPInformationKey {
        HTTPInformationKey(header: header)
    }
}


/// An untyped `Information` instance holding some untyped HTTP header value.
/// You may use the `AnyHTTPInformation.typed(...)` method with a `HTTPInformation` type, to retrieve
/// a typed (and potentially parsed) version of the HTTP Header Information.
public struct AnyHTTPInformation: InformationWithDynamicKey {
    public let key: HTTPInformationKey
    public let value: String

    /// Instantiates a new `AnyHTTPInformation` instance for the given HTTP key and value.
    /// - Parameters:
    ///   - key: The HTTP Header name.
    ///   - value: The raw string based HTTP Header value.
    public init(key: String, rawValue: String) {
        self.key = HTTPInformationKey(header: key)
        self.value = rawValue
    }
}
