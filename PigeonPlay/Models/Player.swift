import Foundation
import SwiftData

enum Gender: String, Codable, CaseIterable {
    case b, g, x

    var displayName: String {
        rawValue.uppercased()
    }
}

enum GenderMatching: String, Codable, CaseIterable {
    case bx, gx

    var displayName: String {
        switch self {
        case .bx: "Bx"
        case .gx: "Gx"
        }
    }
}

@Model
final class Player {
    var name: String
    var gender: Gender
    var defaultMatching: GenderMatching?
    var parentName: String?
    var parentPhone: String?
    var parentEmail: String?

    var effectiveMatching: GenderMatching {
        switch gender {
        case .b: .bx
        case .g: .gx
        case .x: defaultMatching ?? .bx
        }
    }

    init(
        name: String,
        gender: Gender,
        defaultMatching: GenderMatching? = nil,
        parentName: String? = nil,
        parentPhone: String? = nil,
        parentEmail: String? = nil
    ) {
        self.name = name
        self.gender = gender
        self.defaultMatching = defaultMatching
        self.parentName = parentName
        self.parentPhone = parentPhone
        self.parentEmail = parentEmail
    }
}
