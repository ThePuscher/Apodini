//
// Created by Andreas Bauer on 03.07.21.
//

/// A `Information` instance which is not identified via the static `Information.key` property,
/// but instead with a dynamic `InformationWithDynamicKey.key` instance property.
public protocol InformationWithDynamicKey: Information where Value == DynamicKey.Value {
    /// `InformationWithDynamicKey` doe not have a statically defined `InformationKey`.
    /// Instead they have a `DynamicInformationKey` defined via `DynamicKey`
    typealias Key = Never

    /// The `DynamicInformationKey` type uniquely identifying this `Information` instance.
    associatedtype DynamicKey: DynamicInformationKey

    /// The dynamically evaluated `InformationKey` uniquely identifying this instance.
    /// Note the statically defined `InformationKey.key` property is ignored.
    var key: Self.DynamicKey { get }

    /// This method can be used to instantiate a `DynamicInformationInstantiatable` from
    /// the contents of this `InformationWithDynamicKey`.
    /// - Parameter instantiatable: The instantiatable type to be used.
    /// - Returns: The instance of the provided `DynamicInformationInstantiatable`.
    func typed<D: DynamicInformationInstantiatable>(_ instantiatable: D.Type) -> D? where D.DynamicInformation == Self
}

public extension InformationWithDynamicKey {
    /// Default implementation using the default `DynamicInformationInstantiatable.init(rawValue:)`
    /// to instantiate the provided `DynamicInformationInstantiatable`.
    func typed<D: DynamicInformationInstantiatable>(_ instantiatable: D.Type) -> D? where D.DynamicInformation == Self {
        D(rawValue: value)
    }
}

// MARK: Never
public extension InformationWithDynamicKey {
    /// `InformationWithDynamicKey` do not have a static defined `InformationKey`.
    /// Instead the instance property `InformationWithDynamicKey.key` is used.
    static var key: Never {
        fatalError("Cannot access the static InformationKey of the InformationWithDynamicKey \(Self.self)")
    }
}
