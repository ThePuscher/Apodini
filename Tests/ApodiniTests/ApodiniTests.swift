//
//  ApodiniTests.swift
//  
//
//  Created by Paul Schmiedmayer on 7/7/20.
//

import XCTVapor
import FluentSQLiteDriver

class ApodiniTests: XCTestCase {
    // Vapor Application
    var app: Vapor.Application = Application(.testing)
    // Model Objects
    var bird1 = Bird(name: "Swift", age: 5)
    var bird2 = Bird(name: "Corvus", age: 1)
    
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        app.shutdown()
        app = Application(.testing)
        
        app.databases.use(
            .sqlite(.memory),
            as: .init(string: "ApodiniTest"),
            isDefault: true
        )
        
        app.migrations.add(
            CreateBird()
        )
        
        try app.autoMigrate().wait()
        
        
        try bird1.create(on: database()).wait()
        try bird2.create(on: database()).wait()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        let app = try XCTUnwrap(self.app)
        app.shutdown()
    }
    
    
    func tester() throws -> XCTApplicationTester {
        try XCTUnwrap(app.testable())
    }
    
    func database() throws -> Database {
        try XCTUnwrap(self.app.db)
    }
}
