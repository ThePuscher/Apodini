@testable import Apodini
@testable import ApodiniDatabase
@testable import ApodiniREST
@_implementationOnly import Runtime
import Vapor
import XCTApodini


final class DatabaseHandlerTests: ApodiniTests {
    var vaporApp: Vapor.Application {
        self.app.vapor.app
    }
    
    private func pathParameter(for handler: Any) throws -> Parameter<UUID> {
        let mirror = Mirror(reflecting: handler)
        let parameter = mirror.children.compactMap { $0.value as? Parameter<UUID> }.first
        guard let idParameter = parameter else {
            //No point in continuing if there is no parameter
            fatalError("no idParameter found")
        }
        return idParameter
    }
    
    func testCreateHandler() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let dbBird = try bird
            .save(on: self.app.database)
            .transform(to: bird)
            .wait()
        XCTAssertNotNil(dbBird.id)
        
        let creationHandler = Create<Bird>()
        
        
        let response = try XCTUnwrap(mockQuery(handler: creationHandler, value: Bird.self, app: app, queued: bird))
        XCTAssert(response == bird)
        
        let foundBird = try Bird.find(response.id, on: app.database).wait()
        XCTAssertNotNil(foundBird)
        XCTAssertEqual(response, foundBird)
    }
    
    func testCreateAllHandler() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let bird2 = Bird(name: "Hummingbird", age: 25)
        
        let creationHandler = CreateAll<Bird>()
        
        let response = try XCTUnwrap(mockQuery(handler: creationHandler, value: [Bird].self, app: app, queued: [bird, bird2]))

        XCTAssert(!response.isEmpty)
        XCTAssert(response.contains(bird))
        XCTAssert(response.contains(bird2))
        
        let foundBird1 = try XCTUnwrap(try Bird.find(response[0].id, on: app.database).wait())
        XCTAssertNotNil(foundBird1)
        XCTAssert(response.contains(foundBird1))
        let foundBird2 = try XCTUnwrap(try Bird.find(response[1].id, on: app.database).wait())
        XCTAssertNotNil(foundBird2)
        XCTAssert(response.contains(foundBird2))
    }
    
    func testSingleReadHandler() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let dbBird = try bird
            .save(on: self.app.database)
            .transform(to: bird)
            .wait()
        let birdId = try XCTUnwrap(dbBird.id)
        
        let handler = ReadOne<Bird>()
        let endpoint = handler.mockEndpoint(app: app)
        
        let exporter = RESTInterfaceExporter(app)
        let context = endpoint.createConnectionContext(for: exporter)
        
        let uri = URI("http://example.de/test/id")
        let request = Vapor.Request(
            application: vaporApp,
            method: .GET,
            url: uri,
            on: app.eventLoopGroup.next()
        )
        
        let idParameter = try pathParameter(for: handler)
        request.parameters.set("\(idParameter.id)", to: "\(birdId)")
        
        try XCTCheckResponse(
            context.handle(request: request),
            content: dbBird,
            connectionEffect: .close
        )
    }
    
    func testReadHandler() throws {
        let bird1 = Bird(name: "Mockingbird", age: 20)
        let dbBird1 = try bird1
            .save(on: self.app.database)
            .transform(to: bird1)
            .wait()
        
        let bird2 = Bird(name: "Mockingbird", age: 21)
        let dbBird2 = try bird2
            .save(on: self.app.database)
            .transform(to: bird2)
            .wait()
        XCTAssertNotNil(dbBird1.id)
        XCTAssertNotNil(dbBird2.id)
        
        let readHandler = ReadAll<Bird>()
        let endpoint = readHandler.mockEndpoint(app: app)
        
        let exporter = RESTInterfaceExporter(app)
        let context = endpoint.createConnectionContext(for: exporter)
        
        var uri = URI("http://example.de/test/bird?name=Mockingbird")
        var request = Vapor.Request(
            application: vaporApp,
            method: .GET,
            url: uri,
            on: app.eventLoopGroup.next()
        )
        
        let responseValue = try XCTUnwrap(try context.handle(request: request).wait().typed([Bird].self)?.content)
        
        XCTAssert(responseValue.count == 2)
        XCTAssert(responseValue[0].name == "Mockingbird", responseValue.debugDescription)
        XCTAssert(responseValue[1].name == "Mockingbird", responseValue.debugDescription)
        
        uri = URI("http://example.de/test/bird?name=Mockingbird&age=21")
        request = Vapor.Request(
            application: vaporApp,
            method: .GET,
            url: uri,
            on: app.eventLoopGroup.next()
        )
        
        let value = try XCTUnwrap(try context.handle(request: request).wait().typed([Bird].self)?.content)
        
        XCTAssert(value.count == 1)
        XCTAssert(value[0].age == 21, value.debugDescription)
    }
    
    func testUpdateHandleWithSingleParameter() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let dbBird = try bird
            .save(on: self.app.database)
            .transform(to: bird)
            .wait()
        XCTAssertNotNil(dbBird.id)
    
        let parameters: [String: TypeContainer] = [
            "name": TypeContainer(with: "FooBird")
        ]
        
        let handler = Update<Bird>()
        let endpoint = handler.mockEndpoint(app: app)
        
        let exporter = RESTInterfaceExporter(app)
        let context = endpoint.createConnectionContext(for: exporter)
        
        let bodyData = ByteBuffer(data: try JSONEncoder().encode(parameters))
        
        let uri = URI("http://example.de/test/id")
        let request = Vapor.Request(
            application: vaporApp,
            method: .PUT,
            url: uri,
            collectedBody: bodyData,
            on: app.eventLoopGroup.next()
        )
        guard let birdId = dbBird.id else {
            XCTFail("Object found in database has no id")
            return
        }
        let idParameter = try pathParameter(for: handler)
        request.parameters.set("\(idParameter.id)", to: "\(birdId)")
        
        let responseValue = try XCTUnwrap(try context.handle(request: request).wait().typed(Bird.self)?.content)
        
        XCTAssert(responseValue.id == dbBird.id, responseValue.description)
        XCTAssert(responseValue.name == "FooBird", responseValue.description)
        
        guard let newBird = try Bird.find(dbBird.id, on: self.app.database).wait() else {
            XCTFail("Failed to find updated object")
            return
        }
        
        XCTAssertNotNil(newBird)
        XCTAssert(newBird == responseValue, newBird.description)
    }
    
    func testUpdateHandlerWithModel() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let dbBird = try bird
            .save(on: self.app.database)
            .transform(to: bird)
            .wait()
        XCTAssertNotNil(dbBird.id)
        
        let updatedBird = Bird(name: "FooBird", age: 25)
        
        let handler = Update<Bird>()
        let endpoint = handler.mockEndpoint(app: app)
        
        let exporter = RESTInterfaceExporter(app)
        let context = endpoint.createConnectionContext(for: exporter)
        
        let bodyData = ByteBuffer(data: try JSONEncoder().encode(updatedBird))
        
        let uri = URI("http://example.de/test/id")
        let request = Vapor.Request(
            application: vaporApp,
            method: .PUT,
            url: uri,
            collectedBody: bodyData,
            on: app.eventLoopGroup.next()
        )
        guard let birdId = dbBird.id else {
            XCTFail("Object found in database has no id")
            return
        }
        let idParameter = try pathParameter(for: handler)
        request.parameters.set("\(idParameter.id)", to: "\(birdId)")
        
        let responseValue = try XCTCheckResponse(
            context.handle(request: request),
            content: updatedBird,
            connectionEffect: .close
        )
        
        guard let newBird = try Bird.find(dbBird.id, on: self.app.database).wait() else {
            XCTFail("Failed to find updated object")
            return
        }
        
        XCTAssertNotNil(newBird)
        XCTAssert(newBird == responseValue, newBird.description)
    }
    
    func testDeleteHandler() throws {
        let bird = Bird(name: "Mockingbird", age: 20)
        let dbBird = try bird
            .save(on: self.app.database)
            .transform(to: bird)
            .wait()
        XCTAssertNotNil(dbBird.id)
        
        let handler = Delete<Bird>()
        let endpoint = handler.mockEndpoint(app: app)
        
        let exporter = RESTInterfaceExporter(app)
        let context = endpoint.createConnectionContext(for: exporter)
        
        let uri = URI("http://example.de/test/id")
        let request = Vapor.Request(
            application: vaporApp,
            method: .PUT,
            url: uri,
            on: app.eventLoopGroup.next()
        )
        
        guard let birdId = dbBird.id else {
            XCTFail("Object saved in database has no id")
            return
        }
        
        let idParameter = try pathParameter(for: handler)
        request.parameters.set("\(idParameter.id)", to: "\(birdId)")
        
        try XCTCheckResponse(
            context.handle(request: request),
            Empty.self,
            status: .noContent,
            content: nil,
            connectionEffect: .close
        )
        
        expectation(description: "database access").isInverted = true
        waitForExpectations(timeout: 10, handler: nil)
        
        let deletedBird = try Bird.find(dbBird.id, on: app.database).wait()
        XCTAssertNil(deletedBird)
    }
}
