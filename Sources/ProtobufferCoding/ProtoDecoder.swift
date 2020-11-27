//
//  ProtoDecoder.swift
//
//
//  Created by Moritz Schüll on 18.11.20.
//

import Foundation
import Combine


internal class InternalProtoDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any]

    let data: Data
    var dictionary: [Int: Data]

    init(from data: Data) throws {
        self.data = data
        self.dictionary = [:]
        codingPath = []
        userInfo = [:]

        dictionary = try decode(from: data)
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KeyedProtoDecodingContainer(from: self.dictionary))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let keys: [Int] = Array(dictionary.keys)
        let values: [Data] = Array(dictionary.values)
        return UnkeyedProtoDecodingContainer(from: values, keyedBy: keys)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw ProtoError.unsupportedDecodingStrategy("Single value decoding not supported")
    }

    private func decode(from: Data) throws -> [Int: Data] {
        var dictionary = [Int: Data]()

        // points to the byte we want to read next
        var readIndex = 0
        while readIndex < from.count {
            // byte contains: 5 bits of field tag, 3 bits of field data type
            let byte = from[readIndex]
            let fieldTag = Int(byte >> 3) // shift "out" last 3 bytes
            let fieldType = Int(byte & 0b00000111) // only keep last 3 bytes

            // find the field in T with the according CodingKey to the fieldTag
            let (value, newIndex) = try readField(from: from,
                                                  fieldTag: fieldTag,
                                                  fieldType: fieldType,
                                                  fieldStartIndex: readIndex+1)

            #if DEBUG
            print("Size: \(newIndex-readIndex) Bytes")
            #endif

            // set cursor forward to the next field tag
            readIndex = newIndex
            dictionary[fieldTag] = value
        }

        return dictionary
    }

    private func readLengthDelimited(from data: Data, fieldStartIndex: Int) throws -> (Data, Int) {
        // the first byte contains the length of the value
        let length = Int(data[fieldStartIndex])
        // assure we have enough bytes left to read
        if data.count - (fieldStartIndex+1) < length {
            throw ProtoError.decodingError("Not enough data left to code length-delimited value")
        }

        // here we make a copy, since the data here might be a nested data structure
        // this ensures the copy's byte indexing starts with 0 in the case the ProtoDecoder is invoked on it again
        let byteValue = data.subdata(in: (fieldStartIndex+1)..<(fieldStartIndex+length+1))
        return (byteValue, fieldStartIndex+length+1)
    }

    private func readVarInt(from data: Data, fieldStartIndex: Int) throws -> (Data, Int) {
        var varInt = Int64()

        var currentIndex = fieldStartIndex
        var hasNext = 0
        var count = 0
        repeat {
            let byte = data[currentIndex]

            // we need to drop the most significant bit of byte, and
            // append byte to beginning of varint (varints come in reversed order)
            varInt = (Int64(byte & 0b01111111) << (7*count)) | varInt

            // if most significant bit is set, we need to continue with another byte
            hasNext = Int(byte & 0b10000000)
            currentIndex += 1
            count += 1
        } while (hasNext > 0)

        return (Data(bytes: &varInt, count: MemoryLayout.size(ofValue: varInt)),
                currentIndex)
    }

    // Function reads the value of a field from data, starting at byte-index fieldStartIndex.
    // The length of the read data depends on the field-type.
    // The function returns the value, and the starting index of the next field tag.
    private func readField(from data: Data, fieldTag: Int, fieldType: Int, fieldStartIndex: Int) throws -> (Data, Int) {
        switch fieldType {
        case 0: // varint
            let (byteValue, newIndex) = try readVarInt(from: data, fieldStartIndex: fieldStartIndex)
            return (byteValue, newIndex)

        case 1: // 64-bit fixed length
            let byteValue = data[fieldStartIndex...fieldStartIndex+7]
            return (byteValue, fieldStartIndex+8)

        case 2: // length-delimited
            let (byteValue, newIndex) = try readLengthDelimited(from: data, fieldStartIndex: fieldStartIndex)
            return (byteValue, newIndex)

        case 3, 4: // groups are deprecated
            throw ProtoError.unsupportedDataType("Groups are deprecated and not supported by this decoder")

        case 5: // 32-bit fixed length
            let byteValue = data[fieldStartIndex...fieldStartIndex+3]
            return (byteValue, fieldStartIndex+4)

        default:
            throw ProtoError.unknownType(fieldType)
        }
    }
}


public class ProtoDecoder : TopLevelDecoder {

    public init() {}

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        let decoder = try InternalProtoDecoder(from: data)
        return try T(from: decoder)
    }
}
