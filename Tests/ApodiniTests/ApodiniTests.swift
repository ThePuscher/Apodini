//
//  ApodiniTests.swift
//  
//
//  Created by Paul Schmiedmayer on 7/7/20.
//

import XCTApodini
@testable import Apodini
@testable import ApodiniDatabase


class ApodiniTests: XCTApodiniTest {
    // Model Objects
    var bird1 = Bird(name: "Swift", age: 5)
    var bird2 = Bird(name: "Corvus", age: 1)
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try super.addMigrations(CreateBird())
        
        try bird1.create(on: database()).wait()
        try bird2.create(on: database()).wait()
    }
}
