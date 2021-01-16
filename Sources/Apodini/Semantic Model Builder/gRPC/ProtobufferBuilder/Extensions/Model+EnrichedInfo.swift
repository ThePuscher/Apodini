//
//  File.swift
//  
//
//  Created by Nityananda on 12.12.20.
//

extension ProtobufferMessage.Property {
    init?(_ info: EnrichedInfo) throws {
        guard info.typeInfo.type != ArrayDidEncounterCircle.self else {
            return nil
        }
        
        let name = info.propertyInfo?.name ?? ""
        let suffix = isSupportedScalarType(info.typeInfo.type) ? "" : "Message"
        let typeName = try info.typeInfo.compatibleName() + suffix
        let uniqueNumber = info.propertyInfo?.offset ?? 0
        
        let fieldRule: FieldRule
        switch info.cardinality {
        case .zeroToOne:
            fieldRule = .optional
        case .exactlyOne:
            fieldRule = .required
        case .zeroToMany:
            fieldRule = .repeated
        }
        
        self.init(
            fieldRule: fieldRule,
            name: name,
            typeName: typeName,
            uniqueNumber: uniqueNumber
        )
    }
}

extension ProtobufferMessage {
    init?(_ node: Node<Property?>) {
        // If a child is nil, there is a circle in theory.
        // Thus, this message is incomplete.
        // However, a complete message was built closer to the root of the tree.
        let properties = node.children.compactMap { $0.value }
        guard properties.count == node.children.count,
              let name = node.value?.typeName else {
            return nil
        }
        
        self.init(
            name: name,
            properties: Set(properties)
        )
    }
}
