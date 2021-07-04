//
// Created by Andreas Bauer on 04.07.21.
//

import Apodini

public struct DynamicStringKey: DynamicInformationKey {
    public typealias Value = String
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct MockInformation: Information {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct MockInformationWithDynamicKey: InformationWithDynamicKey {
    public let key: DynamicStringKey
    public let value: String

    public init(key: String, value: String) {
        self.key = DynamicStringKey(id: key)
        self.value = value
    }
}

public struct MockIntInformation: DynamicInformationInstantiatable {
    public typealias DynamicInformation = MockInformationWithDynamicKey

    public static var key = DynamicStringKey(id: "MockIntId")

    public let value: Int
    public var rawValue: String {
        String(value)
    }

    public init(_ value: Int) {
        self.value = value
    }

    public init?(rawValue: String) {
        guard let value = Int(argument: rawValue) else {
            return nil
        }

        self.value = value
    }
}
