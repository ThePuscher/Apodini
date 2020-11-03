//
//  SynaxTreeVisitor.swift
//  Apodini
//
//  Created by Paul Schmiedmayer on 6/26/20.
//

import Vapor


enum Scope {
    case nextComponent
    case environment
}


protocol Visitable {
    func visit(_ visitor: SynaxTreeVisitor)
}


class SynaxTreeVisitor {
    private let semanticModelBuilders: [SemanticModelBuilder]
    private(set) var currentNode: ContextNode = ContextNode()
    
    init(semanticModelBuilders: [SemanticModelBuilder] = []) {
        self.semanticModelBuilders = semanticModelBuilders
    }
    
    func enter<C: ComponentCollection>(collection: C) {
        currentNode = currentNode.newContextNode()
    }
    
    func addContext<C: ContextKey>(_ contextKey: C.Type = C.self, value: C.Value, scope: Scope) {
        currentNode.addContext(contextKey, value: value, scope: scope)
    }
    
    func getContextValue<C: ContextKey>(for contextKey: C.Type = C.self) -> C.Value {
        currentNode.getContextValue(for: C.self)
    }
    
    func register<C: Component>(component: C) {
        // We capture the currentContextNode and make a copy that will be used when execuring the request as
        // direcly capturing the currentNode would be influenced by the `resetContextNode()` call and using the
        // currentNode would always result in the last currentNode that was used when visiting the component tree.
        let context = Context(contextNode: currentNode.copy())
        
        for semanticModelBuilder in semanticModelBuilders {
            semanticModelBuilder.register(component: component, withContext: context)
        }
        
        finishedRegisteringContext()
    }
    
    private func finishedRegisteringContext() {
        currentNode.resetContextNode()
    }
    
    func exit<C: ComponentCollection>(collection: C) {
        if let parentNode = currentNode.parentContextNode {
            currentNode = parentNode
        }
    }
}