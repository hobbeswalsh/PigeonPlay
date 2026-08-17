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
    var name: String = ""
    var gender: Gender = Gender.x
    var defaultMatching: GenderMatching?
    var phoneNumber: String?
    var contactIdentifiers: [String] = []

    // CloudKit mirroring requires every relationship to declare an
    // inverse, so these four exist to be the other end of Game and
    // GamePoint's relationships. The declaring side is over there; these
    // stay bare. Nothing reads them yet, but `games` is the cheapest way
    // to ask whether a player sits on an active game's roster.
    var games: [Game] = []
    var appearances: [PointPlayer] = []
    var pointsScored: [GamePoint] = []
    var pointsAssisted: [GamePoint] = []

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
        phoneNumber: String? = nil,
        contactIdentifiers: [String] = []
    ) {
        self.name = name
        self.gender = gender
        self.defaultMatching = defaultMatching
        self.phoneNumber = phoneNumber
        self.contactIdentifiers = contactIdentifiers
    }
}
