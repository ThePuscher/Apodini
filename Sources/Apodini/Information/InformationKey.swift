//
// Created by Andreas Bauer on 03.07.21.
//

import Foundation

/// Uniquely identifies a `Information` instance.
public protocol InformationKey: Hashable {}

/// Uniquely identifies a `InformationWithDynamicKey` instance.
public protocol DynamicInformationKey: InformationKey {
    /// The type of the identified `Information` value.
    /// A definition `InformationWithDynamicKey` using a `DynamicInformationKey`
    /// must match the `InformationWithDynamicKey.Value` to this `Value`.
    associatedtype Value
}


// MARK: InformationKey
extension ObjectIdentifier: InformationKey {}

// MARK: InformationKey
extension Never: DynamicInformationKey {}
