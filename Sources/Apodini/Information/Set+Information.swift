//
//  Set+Information.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

/// Typealias for the `InformationSet`
public typealias InformationSet = Set<AnyInformationEntry>

// MARK: InformationSet Retrieval
public extension InformationSet {
    /// Returns the value of an `Information` instance based on the passed `Information` type.
    /// - Parameter key: The `Information` type that is requested.
    /// - Returns. An instance of `Information.Value` if present in the `InformationSet`.
    subscript<I: Information>(_ key: I.Type = I.self) -> I.Value? {
        first(where: { $0 == AnyInformationEntry(key: I.key) })?.typed(to: key).value
    }

    /// Values of `InformationWithDynamicKey` instances cannot be queried by means of
    /// providing the `Information` type (because the identifier is not evaluated statically, see `DynamicInformationKey`).
    /// Instead use one of the `InformationKey` based subscripts, or a potential application defined subscript.
    subscript<I: Information>(_ key: I.Type = I.self) -> Never where I.Key == Never {
        // e.g. HTTP based exporters provide an [httpHeader: String] subscript.
        fatalError("""
                   A Information with a dynamic key cannot be queried using the type. \
                   Instead use one of the `InformationKey` based subscripts or a application defined one.
                   """)
    }

    /// Returns the value of an `InformationWithDynamicKey` instance based
    /// on the passed `DynamicInformationInstantiatable` type.
    /// - Parameter key: The `DynamicInformationInstantiatable` type that is requested.
    /// - Returns: An instance of `DynamicInformationInstantiatable.Value` if a according `InformationWithDynamicKey`
    ///     is contained in the `InformationSet`.
    subscript<I: DynamicInformationInstantiatable>(_ key: I.Type = I.self) -> I.Value? {
        let result = first(where: { $0 == AnyInformationEntry(key: I.key) })

        if let instantiatable: I = result?.tryTyped() {
            // the information set may contain already an `DynamicInformationInstantiatable` instance
            return instantiatable.value
        }

        return result?
            .typed(to: I.DynamicInformation.self) // turn the entry to the according `InformationWithDynamicKey` type
            .typed(key)? // derive the `DynamicInformationInstantiatable` instance from the `InformationWithDynamicKey`
            .value // return the value of the `DynamicInformationInstantiatable`
    }

    /// Returns the untyped value associated with a given `InformationKey`.
    /// Usage of this method is advised against.
    /// If this method gets called you don't most certainly don't have a `DynamicInformationKey`, but
    /// a "standard" `InformationKey`. Therefore you might want to use the subscript below
    /// if you already know the executed Information value or rely on the subscript which
    /// accepts a `Information` type as the key.
    /// - Parameter key: The `InformationKey` to retrieve the value for.
    /// - Returns: Returns the value associated with the `InformationKey`, if present.
    subscript<I: InformationKey>(_ key: I) -> Any? {
        first(where: { $0 == AnyInformationEntry(key: key) })?.value
    }

    /// Returns the value associated with a given `InformationKey` for a provided expected type.
    /// - Parameter key: The `InformationKey` to retrieve the value for.
    /// - Returns: Returns the value associated with the `InformationKey`, if present.
    subscript<I: InformationKey, V>(_ key: I) -> V? {
        value(for: key)
    }

    /// Returns the value associated with a given `DynamicInformationKey`.
    /// - Parameter key: The `DynamicInformationKey` to retrieve the value for.
    /// - Returns: The value of type `DynamicInformationKey.Value` associated with the `InformationKey`, if present.
    subscript<I: DynamicInformationKey>(_ key: I) -> I.Value? {
        value(for: key)
    }


    private func value<I: InformationKey, V>(for key: I) -> V? {
        guard let element = first(where: { $0 == AnyInformationEntry(key: key) }) else {
            return nil
        }

        guard let casted = element.value as? V else {
            fatalError("\(Self.self)[\(key)] -> \(V.self): Could not cast value \(type(of: element)) to expected \(V.self)")
        }

        return casted
    }
}

// MARK: InformationSet Initializers
public extension InformationSet {
    /// Instantiates a new `InformationSet` from array literal of `AnyInformation`s.
    /// - Parameter elements: The `AnyInformation` elements.
    init(arrayLiteral elements: AnyInformation...) {
        self.init(elements)
    }

    /// Instantiates a new `InformationSet` from the provided `AnyInformation` `Sequence`.
    /// - Parameter sequence: The `Sequence` of `AnyInformation`.
    init<Source: Sequence>(_ sequence: Source) where Source.Element == AnyInformation {
        self = .init(sequence.map { $0.entry() })
    }
}

// MARK: InformationSet Operations
public extension InformationSet {
    /// Inserts a new `Information` into the `InformationSet`.
    @discardableResult
    mutating func insert<I: Information>(_ newMember: I) -> (inserted: Bool, memberAfterInsert: Element) {
        insert(AnyInformationEntry(newMember))
    }

    /// Updates a `Information` member in the `InformationSet`.
    @discardableResult
    mutating func update<I: Information>(with newMember: I) -> I? {
        update(with: AnyInformationEntry(newMember))?.typed()
    }

    /// Removes a `Information` instance from the `InformationSet`.
    @discardableResult
    mutating func remove<I: Information>(_ member: I) -> I? {
        remove(AnyInformationEntry(member))?.typed()
    }
}
