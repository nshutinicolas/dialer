//
//  MeterNumber.swift
//  Dialer
//
//  Created by Cédric Bahirwe on 04/01/2022.
//

import Foundation

struct MeterNumber: Equatable, Identifiable, Codable {
    
    let value: String
    var id: String { value }
    
    init(_ value: String) throws {
        let cleanValue = Self.cleanNumber(value)
        guard cleanValue.isEmpty == false else { throw MeterNumberError.emptyMeterNumber }
        guard cleanValue.allSatisfy(\.isNumber) else { throw MeterNumberError.invalidMeterNumber }
        
        self.value = cleanValue
    }
    
    enum MeterNumberError: String, Error {
        case emptyMeterNumber = "Meter can not be empty."
        case invalidMeterNumber = "Meter Number should only contains digits between 0-9."
        
    }
    
}

extension MeterNumber {
    private static func cleanNumber(_ number: String) -> String {
        // Remove middle white spaces
        var cleanNumber = number.replacingOccurrences(of: " ", with: "")
        
        // Trim white spaces and new lines
        cleanNumber = cleanNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanNumber
    }
}
