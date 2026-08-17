import Foundation
import SwiftData

enum DrawingElement: Codable {
    case stroke(points: [CGPoint], color: String, lineWidth: CGFloat)
    case arrow(from: CGPoint, to: CGPoint, color: String)
    case circle(center: CGPoint, color: String)
}

@Model
final class SavedPlay {
    var name: String = ""
    var elements: [DrawingElement] = []
    // See Game.date: only a record arriving without one lands here.
    var dateCreated: Date = Date.distantPast

    init(name: String, elements: [DrawingElement] = [], dateCreated: Date = Date()) {
        self.name = name
        self.elements = elements
        self.dateCreated = dateCreated
    }
}
