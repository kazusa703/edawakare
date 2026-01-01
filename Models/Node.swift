// Models/Node.swift

import Foundation

struct Node: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let text: String
    let positionX: Double
    let positionY: Double
    let isCenter: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case text
        case positionX = "position_x"
        case positionY = "position_y"
        case isCenter = "is_center"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postId = try container.decode(UUID.self, forKey: .postId)
        text = try container.decode(String.self, forKey: .text)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        isCenter = try container.decodeIfPresent(Bool.self, forKey: .isCenter) ?? false
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(postId, forKey: .postId)
        try container.encode(text, forKey: .text)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(isCenter, forKey: .isCenter)
    }
    
    init(id: UUID = UUID(), postId: UUID, text: String, positionX: Double, positionY: Double, isCenter: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.postId = postId
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.isCenter = isCenter
        self.createdAt = createdAt
    }
}
