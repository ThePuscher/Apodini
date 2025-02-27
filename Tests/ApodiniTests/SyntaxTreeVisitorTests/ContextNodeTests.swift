//
// Created by Andreas Bauer on 20.11.20.
//

import XCTest
import XCTApodini
@testable import Apodini


struct TestComponent: Handler {
    let type: Int

    init(_ type: Int) {
        self.type = type
    }

    func handle() -> String {
        "\(type)"
    }
}


struct IntContextKey: ContextKey {
    typealias Value = Int
    static var defaultValue: Int = 0
}

struct IntOptionalContextKey: OptionalContextKey {
    typealias Value = Int
}

struct IntAdditionContextKey: ContextKey {
    static var defaultValue: Int = 2

    static func reduce(value: inout Int, nextValue: Int) {
        value += nextValue
    }
}

struct StringContextKey: OptionalContextKey {
    typealias Value = String
}

struct IntArrayContextKey: OptionalContextKey {
    typealias Value = [Int]
}

struct IllegalOptionalContextKey: OptionalContextKey {
    // The Value of a ContextKey MUST NOT be an Optional type
    typealias Value = String?
}


struct IntModifier<C: Component>: Modifier {
    let component: C
    let scope: Scope
    let value: Int

    init(_ component: C, scope: Scope, value: Int) {
        self.component = component
        self.scope = scope
        self.value = value
    }

    func parseModifier(_ visitor: SyntaxTreeVisitor) {
        visitor.addContext(IntContextKey.self, value: value, scope: scope)
    }
}

extension IntModifier: Handler, HandlerModifier, HandlerMetadataNamespace where ModifiedComponent: Handler {
    typealias Response = ModifiedComponent.Response
}


struct OptionalIntModifier<C: Component>: Modifier {
    let component: C
    let scope: Scope
    let value: Int

    init(_ component: C, scope: Scope, value: Int) {
        self.component = component
        self.scope = scope
        self.value = value
    }

    func parseModifier(_ visitor: SyntaxTreeVisitor) {
        visitor.addContext(IntOptionalContextKey.self, value: value, scope: scope)
    }
}

extension OptionalIntModifier: Handler, HandlerModifier, HandlerMetadataNamespace where ModifiedComponent: Handler {
    typealias Response = ModifiedComponent.Response
}


struct IntAdditionModifier<C: Component>: Modifier {
    let component: C
    let scope: Scope
    let value: Int

    init(_ component: C, scope: Scope, value: Int) {
        self.component = component
        self.scope = scope
        self.value = value
    }

    func parseModifier(_ visitor: SyntaxTreeVisitor) {
        visitor.addContext(IntAdditionContextKey.self, value: value, scope: scope)
    }
}

extension IntAdditionModifier: Handler, HandlerModifier, HandlerMetadataNamespace where ModifiedComponent: Handler {
    typealias Response = ModifiedComponent.Response
}

struct StringModifier<C: Component>: Modifier {
    let component: C
    let scope: Scope
    let value: String

    init(_ component: C, scope: Scope, value: String) {
        self.component = component
        self.scope = scope
        self.value = value
    }

    func parseModifier(_ visitor: SyntaxTreeVisitor) {
        visitor.addContext(StringContextKey.self, value: value, scope: scope)
    }
}

extension StringModifier: Handler, HandlerModifier, HandlerMetadataNamespace where ModifiedComponent: Handler {
    typealias Response = ModifiedComponent.Response
}

struct IntArrayModifier<C: Component>: Modifier {
    let component: C
    let scope: Scope
    let value: [Int]

    init(_ component: C, scope: Scope, value: [Int]) {
        self.component = component
        self.scope = scope
        self.value = value
    }

    func parseModifier(_ visitor: SyntaxTreeVisitor) {
        visitor.addContext(IntArrayContextKey.self, value: value, scope: scope)
    }
}

extension IntArrayModifier: Handler, HandlerModifier, HandlerMetadataNamespace where ModifiedComponent: Handler {
    typealias Response = ModifiedComponent.Response
}

extension Component {
    func modifier(_ scope: Scope, value: Int) -> IntModifier<Self> {
        IntModifier(self, scope: scope, value: value)
    }

    func optionalModifier(_ scope: Scope, value: Int) -> OptionalIntModifier<Self> {
        OptionalIntModifier(self, scope: scope, value: value)
    }

    func addingInt(_ scope: Scope, value: Int) -> IntAdditionModifier<Self> {
        IntAdditionModifier(self, scope: scope, value: value)
    }

    func string(_ scope: Scope, value: String) -> StringModifier<Self> {
        StringModifier(self, scope: scope, value: value)
    }

    func arrayInt(_ scope: Scope, value: [Int]) -> IntArrayModifier<Self> {
        IntArrayModifier(self, scope: scope, value: value)
    }
}


/// Includes regression testing for https://github.com/Apodini/Apodini/issues/12.
/// Read through this issues before doing any changes!
final class ContextNodeTests: ApodiniTests {
    var groupWithSingleComponent: some Component {
        Group("test") {
            TestComponent(1)
        }.modifier(.current, value: 1)
    }

    func testGroupWithSingleComponent() {
        class TestSemanticModelBuilder: SemanticModelBuilder {
            override func register<H: Handler>(handler: H, withContext context: Context) {
                if let testComponent = handler as? TestComponent {
                    let intValue = context.get(valueFor: IntContextKey.self)

                    switch testComponent.type {
                    case 1:
                        // 0 is the default value for IntNextComponentContextKey
                        XCTAssertEqual(intValue, 0, "TestComponent is seemingly sharing the same ContextNode with the Group")
                    default:
                        XCTFail("Received unknown component type \(testComponent.type)")
                    }
                } else {
                    XCTFail("Received registration for unexpected component type \(handler)")
                }
            }
        }

        let visitor = SyntaxTreeVisitor(modelBuilder: TestSemanticModelBuilder(app))
        groupWithSingleComponent.accept(visitor)
        visitor.finishParsing()
    }
    
    
    var groupWithComponentAndGroup: some Component {
        Group("test") {
            TestComponent(1)
                .modifier(.environment, value: 1)
            Group("test2") {
                TestComponent(2)

                Group("test3") {
                    TestComponent(3)
                        .modifier(.current, value: 4)
                    TestComponent(4)
                }.modifier(.current, value: 99)
            }.modifier(.environment, value: 2)
        }.modifier(.environment, value: 3)
    }

    func testGroupWithComponentAndGroup() {
        class TestSemanticModelBuilder: SemanticModelBuilder {
            override func register<H: Handler>(handler: H, withContext context: Context) {
                if let testComponent = handler as? TestComponent {
                    let path = context.get(valueFor: PathComponentContextKey.self)
                    let pathString = path.asPathString()
                    let intValue = context.get(valueFor: IntContextKey.self)

                    switch testComponent.type {
                    case 1:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 1)
                    case 2:
                        XCTAssertEqual(pathString, "test/test2")
                        XCTAssertEqual(intValue, 2)
                    case 3:
                        XCTAssertEqual(pathString, "test/test2/test3")
                        XCTAssertEqual(intValue, 4)
                    case 4:
                        XCTAssertEqual(pathString, "test/test2/test3")
                        XCTAssertEqual(intValue, 2)
                    default:
                        XCTFail("Received unknown component type \(testComponent.type)")
                    }
                } else {
                    XCTFail("Received registration for unexpected component type \(handler)")
                }
            }
        }

        let visitor = SyntaxTreeVisitor(modelBuilder: TestSemanticModelBuilder(app))
        groupWithComponentAndGroup.accept(visitor)
        visitor.finishParsing()
    }
    
    
    var groupWithGroupAndComponent: some Component {
        Group("test") {
            Group("test2") {
                TestComponent(2)
            }.modifier(.environment, value: 1)
            TestComponent(1)
        }
    }

    func testGroupWithGroupAndComponent() {
        class TestSemanticModelBuilder: SemanticModelBuilder {
            override func register<H: Handler>(handler: H, withContext context: Context) {
                if let testComponent = handler as? TestComponent {
                    let path = context.get(valueFor: PathComponentContextKey.self)
                    let pathString = path.asPathString()
                    let intValue = context.get(valueFor: IntContextKey.self)

                    switch testComponent.type {
                    case 1:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 0) // 0 is the default value for IntEnvironmentContextKey
                    case 2:
                        XCTAssertEqual(pathString, "test/test2")
                        XCTAssertEqual(intValue, 1)
                    default:
                        XCTFail("Received unknown component type \(testComponent.type)")
                    }
                } else {
                    XCTFail("Received registration for unexpected component type \(handler)")
                }
            }
        }

        let visitor = SyntaxTreeVisitor(modelBuilder: TestSemanticModelBuilder(app))
        groupWithGroupAndComponent.accept(visitor)
        visitor.finishParsing()
    }

    var groupWithOptionalModifier: some Component {
        Group("test") {
            Group("test2") {
                TestComponent(3)
                TestComponent(4)
                    .optionalModifier(.environment, value: 4)
            }.optionalModifier(.environment, value: 3)
            TestComponent(1)
            TestComponent(2)
                .optionalModifier(.current, value: 2)
            TestComponent(5)
                .optionalModifier(.current, value: 2)
                .optionalModifier(.current, value: 5)
        }
    }

    func testGroupWithOptionalModifier() {
        class TestSemanticModelBuilder: SemanticModelBuilder {
            override func register<H: Handler>(handler: H, withContext context: Context) {
                if let testComponent = handler as? TestComponent {
                    let path = context.get(valueFor: PathComponentContextKey.self)
                    let pathString = path.asPathString()
                    let intValue = context.get(valueFor: IntOptionalContextKey.self)

                    switch testComponent.type {
                    case 1:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, nil)
                    case 2:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 2)
                    case 3:
                        XCTAssertEqual(pathString, "test/test2")
                        XCTAssertEqual(intValue, 3)
                    case 4:
                        XCTAssertEqual(pathString, "test/test2")
                        XCTAssertEqual(intValue, 4)
                    case 5:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 5)
                    default:
                        XCTFail("Received unknown component type \(testComponent.type)")
                    }
                } else {
                    XCTFail("Received registration for unexpected component type \(handler)")
                }
            }
        }

        let visitor = SyntaxTreeVisitor(modelBuilder: TestSemanticModelBuilder(app))
        groupWithOptionalModifier.accept(visitor)
        visitor.finishParsing()
    }

    // This test case explicitly test that the reduce function
    // is called with the default value
    // default value for the addition is 2
    var groupWithIntAddition: some Component {
        Group("test") {
            TestComponent(1)
            TestComponent(2)
                .addingInt(.current, value: 1)
        }.addingInt(.environment, value: 1)
    }

    func testGroupWithIntAddition() {
        class TestSemanticModelBuilder: SemanticModelBuilder {
            override func register<H: Handler>(handler: H, withContext context: Context) {
                if let testComponent = handler as? TestComponent {
                    let path = context.get(valueFor: PathComponentContextKey.self)
                    let pathString = path.asPathString()
                    let intValue = context.get(valueFor: IntAdditionContextKey.self)

                    switch testComponent.type {
                    case 1:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 1)
                    case 2:
                        XCTAssertEqual(pathString, "test")
                        XCTAssertEqual(intValue, 2)
                    default:
                        XCTFail("Received unknown component type \(testComponent.type)")
                    }
                } else {
                    XCTFail("Received registration for unexpected component type \(handler)")
                }
            }
        }

        let visitor = SyntaxTreeVisitor(modelBuilder: TestSemanticModelBuilder(app))
        groupWithIntAddition.accept(visitor)
        visitor.finishParsing()
    }

    func testDefaultReduceForStringBasedContextKeys() {
        let handler = TestComponent(1)
            .string(.current, value: "Hello")
            .string(.current, value: "World")

        let visitor = SyntaxTreeVisitor()
        handler.accept(visitor)

        let context = visitor.currentNode.export()

        XCTAssertEqual(context.get(valueFor: StringContextKey.self), "World")
    }

    func testDefaultReduceForArrayBasedContextKeys() {
        let handler = TestComponent(1)
            .arrayInt(.current, value: [1, 2])
            .arrayInt(.current, value: [3, 4])

        let visitor = SyntaxTreeVisitor()
        handler.accept(visitor)

        let context = visitor.currentNode.export()

        XCTAssertEqual(context.get(valueFor: IntArrayContextKey.self), [1, 2, 3, 4])
    }

    func testAddingIllegalContextKey() {
        let visitor = SyntaxTreeVisitor()
        XCTAssertRuntimeFailure(visitor.addContext(IllegalOptionalContextKey.self, value: nil, scope: .current))
        XCTAssertRuntimeFailure(visitor.addContext(IllegalOptionalContextKey.self, value: "test", scope: .current))
    }
}
