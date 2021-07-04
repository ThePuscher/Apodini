//
//  Information.swift
//  
//
//  Created by Paul Schmiedmayer on 5/26/21.
//

import Foundation

/// Describes a type erased version of an `Information` instance.
public protocol AnyInformation {
    /// Internal method turning an `Information` instance into a `AnyInformationEntry`.
    func entry() -> AnyInformationEntry
}


/// Information describes additional metadata that can be attached to a `Response` or can be found in the `ConnectionContext` in the `@Environment` of a `Handler`.
@dynamicMemberLookup
public protocol Information: AnyInformation {
    /// The `InformationKey` type uniquely identified this `Information` instance.
    associatedtype Key: InformationKey
    /// The value associated with the type implementing `Information`.
    associatedtype Value
    

    /// A key identifying the type implementing `Information`.
    static var key: Self.Key { get }
    
    
    /// The value associated with the type implementing `Information`
    var value: Value { get }
    
    
    /// Enables developers to directly access properties of the `Value` using the `Information`
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T { get }
}

// MARK: dynamicMemberLookup
public extension Information {
    /// Enables developers to directly access properties of the `Value` using the `Information`
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        value[keyPath: keyPath]
    }
}

// MARK: Default Key
public extension Information {
    /// By default, the `ObjectIdentifier` of the implementing `Information` type will be used.
    static var key: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }
}

// MARK: AnyInformation
public extension Information {
    /// Default implementation to derive the `AnyInformationEntry`
    func entry() -> AnyInformationEntry {
        AnyInformationEntry(self)
    }
}
