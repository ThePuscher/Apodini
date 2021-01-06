//
//  Bird.swift
//  
//
//  Created by Paul Schmiedmayer on 7/7/20.
//

import Fluent
import Vapor
import Apodini

final class Bird: Model, Content {
    static var schema: String = "Birds"
    
    
    @ID
    var id: UUID?
    @Field(key: "name")
    var name: String
    @Field(key: "age")
    var age: Int
    
    
    init(name: String, age: Int) {
        self.id = nil
        self.name = name
        self.age = age
    }
    
    init() {}
}


struct CreateBird: Migration {
    func prepare(on database: Fluent.Database) -> EventLoopFuture<Void> {
        database.schema(Bird.schema)
            .id()
            .field("name", .string, .required)
            .field("age", .int, .required)
            .create()
    }

    func revert(on database: Fluent.Database) -> EventLoopFuture<Void> {
        database.schema(Bird.schema).delete()
    }
}

extension Bird: Equatable {
    static func == (lhs: Bird, rhs: Bird) -> Bool {
        var result = lhs.name == rhs.name && lhs.age == rhs.age
        
        if let lhsId = lhs.id, let rhsId = rhs.id {
            result = result && lhsId == rhsId
        }
        
        return result
    }
}