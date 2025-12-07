import Foundation

// Top-level response Gemini will return
struct PanelResponse: Codable {
    var panels: [Panel]
}

// One panel schedule (LP-1, MDP, etc.)
struct Panel: Identifiable, Codable {
    var id: String = UUID().uuidString
    var sourcePDFID: String?        // <--- 1. ADD THIS PROPERTY
    var name: String            // e.g. "LP-1"
    var location: String?       // e.g. "Electrical Room 1"
    var voltage: String?        // e.g. "208/120V"
    var phases: String?         // e.g. "3PH, 4W"
    var mains: String?          // e.g. "225A MLO" or "225A MCB"
    var fedFrom: String?
    var circuits: [Circuit]
    
    enum CodingKeys: String, CodingKey {
        case sourcePDFID        // <--- 2. ADD THIS KEY
            case name, location, voltage, phases, mains, fedFrom, circuits
        }
}

// One circuit row in the panel
struct Circuit: Identifiable, Codable {
    var id: String = UUID().uuidString

    var number: Int             // circuit number, e.g. 1, 2, 3...
    var description: String?    // load description
    var tripAmps: Int?          // breaker size, e.g. 20, 30
    var poles: Int?            // 1, 2, or 3
    
    enum CodingKeys: String, CodingKey {
        case number, description, tripAmps, poles
    }
    // Later we can add:
    // var phase: String?       // "A", "B", "C" etc.
}
extension Panel {
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "location": location ?? "",
            "voltage": voltage ?? "",
            "mains": mains ?? "",
            "phases": phases ?? "",
            "fedFrom": fedFrom ?? "",
            "circuits": circuits.map { $0.toDictionary() }
        ]
    }
}

extension Circuit {
    func toDictionary() -> [String: Any] {
        return [
            "number": number,
            "description": description ?? "",
            "tripAmps": tripAmps as Any,
            "poles": poles as Any
        ]
    }
}
