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
        if let (untypedInformation, rawValue) = StandardInformationInstantiatableVisitor()(information) {
            self.information = untypedInformation
            self.value = rawValue
        } else {
            self.information = information
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
    func callAsFunction<T: DynamicInformationInstantiatable>(_ value: T) -> (AnyInformation, Any) {
        (value.untyped(), value.rawValue)
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
    init() {}
    init(key: Never, rawValue: Never) {
        fatalError("Inaccessible")
    }
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
