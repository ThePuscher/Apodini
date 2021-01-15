//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08.12.20.
//
import Apodini
import Foundation
import Fluent
@_implementationOnly import Vapor
@_implementationOnly import Runtime

internal struct QueryBuilder<Model: DatabaseModel> {
    internal var debugDescription: String {
        parameters.debugDescription
    }
    
    private let type: Model.Type

    private var fieldKeys: [FieldKey] {
        type.keys
    }

    internal var parameters: [FieldKey: AnyConcreteCodable] = [:]

    init(type: Model.Type, parameters: [FieldKey: AnyConcreteCodable]) {
        self.type = type
        self.parameters = parameters
    }
    
    internal func execute(on database: Fluent.Database) -> EventLoopFuture<[Model]> {
        var queryBuilder = Model.query(on: database)
        for (key, value) in parameters {
            queryBuilder.filter(key: key, method: .equal, codableValue: value)
        }
        return queryBuilder.all()
    }
    
    @discardableResult
    internal static func fieldKeys<Model: DatabaseModel>(for type: Model.Type) -> [FieldKey] {
        type.keys
    }
    
    internal static func info(for type: Model.Type) -> [ModelInfo] {
        var modelInfo: [ModelInfo] = []
        let keys = type.keys
        for (index, child) in Mirror(reflecting: Model()).children.enumerated() {
//            print(child)
            let key = keys[index]
            if let idVisitable = child.value as? VisitableIDProperty {
                let concreteCodable = idVisitable.accept(ConcreteIDPropertyVisitor())
                modelInfo.append(ModelInfo(key: key, value: concreteCodable))
//                print(Self.parameter(for: concreteCodable))
//                print(concreteCodable)
            }
            if let fieldVisitable = child.value as? VisitableFieldProperty {
                let concreteCodable = fieldVisitable.accept(ConcreteTypeVisitor())
                modelInfo.append(ModelInfo(key: key, value: concreteCodable))
//                print(Self.parameter(for: concreteCodable))
//                print(concreteCodable)
            }
        }
        return modelInfo
    }
    
    static func parameter<T: Codable>(for: T? = nil) -> Parameter<T?> {
        Parameter<T?>(.http(.query))
    }
}

protocol UpdatableFieldPropertyVisitor where Value: Codable {
    associatedtype Value

    func visit<Model, V>(_ property: inout FieldProperty<Model, V>) -> Value
}

struct ConcreteUpdatableFieldPropertyVisitor: UpdatableFieldPropertyVisitor {
    typealias Value = Bool
    
    let updater: AnyConcreteCodable
    
    func visit<Model, V>(_ property: inout FieldProperty<Model, V>) -> Bool where Model : Fields, V : Decodable, V : Encodable {
        print(property.value)
        print(updater.wrappedValue)
        print(updater.wrappedType)
        if case 
        if let conformedValue = Int(5) as? V {
            property.value = 5 as! V
            print(property.value)
            return true
        }
        return false
    }
}

protocol UpdatableFieldProperty {
    func accept<Visitor: UpdatableFieldPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value where Visitor.Value == Bool
}

protocol FieldPropertyVisitor where Value: Codable {
    associatedtype Value

    func visit<Model, V>(_ property: FieldProperty<Model, V>) -> Value
    
    static func unwrap<Self>(_ type: Any) -> Self
}

struct ConcreteTypeVisitor: FieldPropertyVisitor {
    typealias Value = AnyConcreteCodable
    
    func visit<Model, V>(_ property: FieldProperty<Model, V>) -> Value where Model : Fields, V : Decodable, V : Encodable {
        print(property.wrappedValue)
        return AnyConcreteCodable(property.wrappedValue)
    }

    static func unwrap<ConcreteTypeVisitor>(_ type: Any) -> ConcreteTypeVisitor {
        return type as! ConcreteTypeVisitor
    }

}
//
//struct GenericTypeVisitor: FieldPropertyVisitor {
//    typealias Value = AnyGenericCodable
//
//    func visit<Model, V>(_ property: FieldProperty<Model, V>) -> Value where Model : Fields, V : Decodable, V : Encodable {
////        return AnyGenericCodable(AnyParameter(Parameter<V>(.http(.query))), key: property.key)
//        return AnyGenericCodable(V.self, key: property.key)
//    }
//
//    static func unwrap<ConcreteTypeVisitor>(_ type: Any) -> ConcreteTypeVisitor {
//        return type as! ConcreteTypeVisitor
//    }
//
//}

protocol VisitableFieldProperty {
    func accept<Visitor: FieldPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value where Visitor.Value == AnyConcreteCodable
    func accept<Visitor: FieldPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value where Visitor.Value == AnyGenericCodable
}

extension FieldProperty: VisitableFieldProperty {

    func accept<Visitor>(_ visitor: Visitor) -> Visitor.Value where Visitor : FieldPropertyVisitor {
        visitor.visit(self)
    }

}

extension FieldProperty: UpdatableFieldProperty {
    func accept<Visitor>(_ visitor: Visitor) -> Visitor.Value where Visitor : UpdatableFieldPropertyVisitor, Visitor.Value == Bool {
        var varSelf = self
        return visitor.visit(&varSelf)
    }
}

protocol IDPropertyVisitor where Value: Codable {
    associatedtype Value
    
    func visit<Model, V>(_ property: IDProperty<Model, V>) -> Value where Model: DatabaseModel
}

protocol VisitableIDProperty {
    
    func accept<Visitor: IDPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value where Visitor.Value == AnyConcreteCodable
    func accept<Visitor: IDPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value where Visitor.Value == AnyGenericCodable
}

struct ConcreteIDPropertyVisitor: IDPropertyVisitor {
    typealias Value = AnyConcreteCodable
    
    func visit<Model, V>(_ property: IDProperty<Model, V>) -> AnyConcreteCodable where Model : DatabaseModel, V : Decodable, V : Encodable {
        AnyConcreteCodable(property.wrappedValue)
    }
}

struct GenericIDPropertyVisitor: IDPropertyVisitor {
    typealias Value = AnyGenericCodable
    
    func visit<Model, V>(_ property: IDProperty<Model, V>) -> AnyGenericCodable where Model : DatabaseModel, V : Decodable, V : Encodable {
        AnyGenericCodable(V.self, key: property.key)
    }
}

extension IDProperty: VisitableIDProperty where Model: DatabaseModel {
    func accept<Visitor>(_ visitor: Visitor) -> Visitor.Value where Visitor : IDPropertyVisitor {
        visitor.visit(self)
    }
    
}

extension Fluent.QueryBuilder {
    
    func filter(key: FieldKey, method: DatabaseQuery.Filter.Method, codableValue: AnyConcreteCodable) {
        switch codableValue.wrappedType {
        case .bool(let value):
            self.filter(key, method, value)
            break
        case .string(let value):
            self.filter(key, method, value)
            break
        case .int(let value):
            self.filter(key, method, value)
            break
        case .int8(let value):
            self.filter(key, method, value)
            break
        case .int16(let value):
            self.filter(key, method, value)
            break
        case .int32(let value):
            self.filter(key, method, value)
            break
        case .int64(let value):
            self.filter(key, method, value)
            break
        case .uint(let value):
            self.filter(key, method, value)
            break
        case .uint8(let value):
            self.filter(key, method, value)
            break
        case .uint16(let value):
            self.filter(key, method, value)
            break
        case .uint32(let value):
            self.filter(key, method, value)
            break
        case .uint64(let value):
            self.filter(key, method, value)
            break
        case .uuid(let value):
            self.filter(key, method, value)
            break
        case .float(let value):
            self.filter(key, method, value)
            break
        case .double(let value):
            self.filter(key, method, value)
            break
        case .noValue, .none:
            break
        }
    }
    
}

protocol TestPropertyVisitor where Value: Codable {
    associatedtype Value

    func visit(_ value: AnyConcreteCodable) -> Value?
}

struct IntPropertyVisitor: TestPropertyVisitor {
    
    typealias Value = Int
    
    func visit(_ value: AnyConcreteCodable) -> Value? {
        switch value.wrappedType {
        case .int(let intValue):
            return intValue
        default:
            return nil
        }
        
    }
}

struct StringPropertyVisitor: TestPropertyVisitor {
    typealias Value = String
    
    func visit(_ value: AnyConcreteCodable) -> Value? {
        switch value.wrappedType {
        case .string(let stringValue):
            return stringValue
        default:
            return nil
        }
    }
}

protocol VisitableAnyCodable {
    func accept<Visitor: TestPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value? where Visitor.Value == Int
    func accept<Visitor: TestPropertyVisitor>(_ visitor: Visitor) -> Visitor.Value? where Visitor.Value == String
}

extension AnyConcreteCodable: VisitableAnyCodable {
    func accept<Visitor>(_ visitor: Visitor) -> Visitor.Value? where Visitor : TestPropertyVisitor, Visitor.Value == Int {
        visitor.visit(self)
    }
    
    func accept<Visitor>(_ visitor: Visitor) -> Visitor.Value? where Visitor : TestPropertyVisitor, Visitor.Value == String {
        visitor.visit(self)
    }
    
}