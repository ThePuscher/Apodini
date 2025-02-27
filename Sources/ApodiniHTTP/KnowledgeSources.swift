//
//  KnowledgeSources.swift
//  
//
//  Created by Max Obermeier on 30.06.21.
//

import Apodini
import ApodiniExtension
import ApodiniVaporSupport
import Vapor


struct VaporEndpointKnowledge: KnowledgeSource {
    let method: Vapor.HTTPMethod
    
    let pattern: CommunicationalPattern
    
    let path: [Vapor.PathComponent]
    
    let defaultValues: DefaultValueStore
    
    init<B>(_ blackboard: B) throws where B: Blackboard {
        let knowledge = blackboard[ProtocolAgnosticEndpointKnowledge.self]
        
        self.method = Vapor.HTTPMethod(knowledge.operation)
        self.pattern = knowledge.pattern
        self.path = knowledge.path.compactMap { element in
            switch element {
            case .root:
                return nil
            case let .parameter(parameter):
                return .parameter(parameter.name)
            case let .string(string):
                return .constant(string)
            }
        }
        self.defaultValues = knowledge.defaultValues
    }
}

struct ProtocolAgnosticEndpointKnowledge: KnowledgeSource {
    let operation: Apodini.Operation
    
    let pattern: CommunicationalPattern
    
    let path: [EndpointPath]
    
    let defaultValues: DefaultValueStore
    
    init<B>(_ blackboard: B) throws where B: Blackboard {
        self.operation = blackboard[Apodini.Operation.self]
        self.pattern = blackboard[CommunicationalPattern.self]
        self.path = blackboard[EndpointPathComponentsHTTP.self].value
        self.defaultValues = blackboard[DefaultValueStore.self]
    }
}
