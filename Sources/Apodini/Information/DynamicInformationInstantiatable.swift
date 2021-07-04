//
// Created by Andreas Bauer on 03.07.21.
//

/// A `DynamicInformationInstantiatable` represents a special kind of `Information`
/// which can be instantiated from a predefined `InformationWithDynamicKey`.
///
/// This can be used to e.g. create a `InformationWithDynamicKey` which holds the
public protocol DynamicInformationInstantiatable: Information {
    /// The associated `InformationWithDynamicKey` from which this
    /// `DynamicInformationInstantiatable` can be instantiated by calling `DynamicInformationInstantiatable.typed(...)`
    associatedtype DynamicInformation: InformationWithDynamicKey
    /// The `DynamicInformationInstantiatable` inherits the `DynamicInformationKey`
    /// for the `DynamicInformation`.
    typealias Key = DynamicInformation.DynamicKey

    /// The raw value as stored inside the `DynamicInformation`.
    var rawValue: DynamicInformation.Value { get }

    /// Required initializer to instantiate a new `DynamicInformationInstantiatable`
    /// from the value of the `DynamicInformation`
    /// - Parameter rawValue: The raw value as captured by the `InformationWithDynamicKey`
    init?(rawValue: DynamicInformation.Value)
}
