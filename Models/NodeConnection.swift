// Models/NodeConnection.swift

import Foundation

struct NodeConnection: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    var reason: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case fromNodeId = "from_node_id"
        case toNodeId = "to_node_id"
        case reason
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postId = try container.decode(UUID.self, forKey: .postId)
        fromNodeId = try container.decode(UUID.self, forKey: .fromNodeId)
        toNodeId = try container.decode(UUID.self, forKey: .toNodeId)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        
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
        try container.encode(fromNodeId, forKey: .fromNodeId)
        try container.encode(toNodeId, forKey: .toNodeId)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
    
    init(id: UUID = UUID(), postId: UUID, fromNodeId: UUID, toNodeId: UUID, reason: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.postId = postId
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.reason = reason
        self.createdAt = createdAt
    }
}
