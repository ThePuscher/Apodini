//
//  AnyInformationEntry.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

@_implementationOnly import AssociatedTypeRequirementsVisitor

/// Represents an `AnyInformation` entry in an `InformationSet`.
public struct AnyInformationEntry {
    var information: AnyInformation?
    var value: Any?
    private var keyHashInto: (inout Hasher) -> Void

    init<I: Information>(_ information: I) {
        self.information = information

        if let value = StandardInformationInstantiatableVisitor()(information) {
            self.value = value
        } else {
            self.value = information.value
        }

        if let hashFunc = StandardInformationWithDynamicKeyVisitor()(information) {
            self.keyHashInto = hashFunc
        } else {
            self.keyHashInto = I.key.hash
        }
    }

    init<I: InformationKey>(key: I) {
        self.keyHashInto = key.hash
    }

    /// Tries to return the typed version of the wrapped Information instance.
    /// - Parameter type: The `Information` type for which we should try to cast the instance to.
    /// - Returns: Returns the casted `Information` instance or nil if types didn't match.
    public func tryTyped<T: Information>(of type: T.Type = T.self) -> T? {
        guard let information = information else {
            fatalError("Tried typing an AnyInformation which was instantiated from key only")
        }

        return information as? T
    }

    /// Returns the type version of the wrapped `Information` instance.
    /// - Parameter type: The `Information` type
    /// - Returns: Returns the casted `Information` instance.
    public func typed<T: Information>(to type: T.Type = T.self) -> T {
        guard let information = information else {
            fatalError("Tried typing an AnyInformation which was instantiated from key only")
        }
        guard let typed = information as? T else {
            fatalError("Tried typing AnyInformation with type \(information.self) to \(T.self)")
        }

        return typed
    }

    /// - Returns: Returns the wrapped information instance as a type erased `AnyInformation`
    public func any() -> AnyInformation {
        guard let information = information else {
            fatalError("Tried typing an AnyInformation which was instantiated from key only")
        }

        return information
    }
}

extension AnyInformationEntry: Hashable {
    public func hash(into hasher: inout Hasher) {
        keyHashInto(&hasher)
    }

    public static func == (lhs: AnyInformationEntry, rhs: AnyInformationEntry) -> Bool {
        var lhsHasher = Hasher()
        var rhsHasher = Hasher()

        lhs.hash(into: &lhsHasher)
        rhs.hash(into: &rhsHasher)

        return lhsHasher.finalize() == rhsHasher.finalize()
    }
}


private protocol InformationInstantiatableVisitor: AssociatedTypeRequirementsVisitor {
    associatedtype Visitor = InformationInstantiatableVisitor
    associatedtype Input = DynamicInformationInstantiatable
    associatedtype Output

    func callAsFunction<T: DynamicInformationInstantiatable>(_ value: T) -> Output
}

private extension InformationInstantiatableVisitor {
    @inline(never)
    @_optimize(none)
    func _test() {
        _ = self(TestDynamicInformationInstantiatable())
    }
}

private struct StandardInformationInstantiatableVisitor: InformationInstantiatableVisitor {
    func callAsFunction<T: DynamicInformationInstantiatable>(_ value: T) -> Any {
        value.rawValue
    }
}


private protocol InformationWithDynamicKeyVisitor: AssociatedTypeRequirementsVisitor {
    associatedtype Visitor = InformationWithDynamicKeyVisitor
    associatedtype Input = InformationWithDynamicKey
    associatedtype Output

    func callAsFunction<T: InformationWithDynamicKey>(_ value: T) -> Output
}

private extension InformationWithDynamicKeyVisitor {
    @inline(never)
    @_optimize(none)
    func _test() {
        _ = self(TestInformationWithDynamicKey())
    }
}

private struct StandardInformationWithDynamicKeyVisitor: InformationWithDynamicKeyVisitor {
    func callAsFunction<T: InformationWithDynamicKey>(_ value: T) -> (inout Hasher) -> Void {
        value.key.hash
    }
}


private struct TestInformationWithDynamicKey: InformationWithDynamicKey {
    fileprivate var key: Never {
        fatalError("Inaccessible")
    }
    fileprivate var value: DynamicKey.Value {
        fatalError("Inaccessible")
    }
}

private struct TestDynamicInformationInstantiatable: DynamicInformationInstantiatable {
    typealias Value = Never
    typealias DynamicInformation = TestInformationWithDynamicKey

    static var key: Never {
        fatalError("Inaccessible")
    }
    var rawValue: Never {
        fatalError("Inaccessible")
    }
    var value: Never {
        fatalError("Inaccessible")
    }

    init () {}
    init?(rawValue: DynamicInformation.Value) {
        fatalError("Inaccessible")
    }
    init(_ value: Value) {
        fatalError("Inaccessible")
    }
}

/*
/// Type erasured `Information`
/// Information describes additional metadata that can be attached to a `Response` or can be found in the `ConnectionContext` in the `@Environment` of a `Handler`.
public struct AnyInformation {
    /// A key identifying the type erased `Information` type
    public let key: String
    /// The value associated with the type erased `Information` type
    let value: Any
    /// The raw `String` representation associated with the type erased `Information` type
    public let rawValue: String
    
    
    /// Create a new `AnyInformation` instance using an `Information` instance
    public init<I: Information>(_ information: I) {
        self.key = I.key
        self.value = information.value
        self.rawValue = information.rawValue
    }
    
    /// Create a new `AnyInformation` instance using a `key` `value` pair.
    /// - Parameters:
    ///   - key: The key of the `Information`
    ///   - rawValue: The raw `String` value of the `Information`
    public init(key: String, rawValue: String) {
        switch key {
        case Authorization.key:
            guard let authorization = Authorization(rawValue: rawValue) else {
                fallthrough
            }
            self = .init(authorization)
            return
        case Cookies.key:
            guard let cookies = Cookies(rawValue: rawValue) else {
                fallthrough
            }
            self = .init(cookies)
            return
        case ETag.key:
            guard let etag = ETag(rawValue: rawValue) else {
                fallthrough
            }
            self = .init(etag)
            return
        case Expires.key:
            guard let expires = Expires(rawValue: rawValue) else {
                fallthrough
            }
            self = .init(expires)
            return
        case RedirectTo.key:
            guard let redirectTo = RedirectTo(rawValue: rawValue) else {
                fallthrough
            }
            self = .init(redirectTo)
            return
        default:
            self.key = key
            self.value = rawValue
            self.rawValue = rawValue
        }
    }
    
    
    func typed<I: Information>(_ type: I.Type = I.self) -> I? {
        guard let value = value as? I.Value else {
            return nil
        }
        
        return I(value)
    }
}

extension AnyInformation: Hashable {
    public static func == (lhs: AnyInformation, rhs: AnyInformation) -> Bool {
        lhs.key == rhs.key
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

*/
