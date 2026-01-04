// Models/DraftPost.swift

import Foundation

struct DraftPost: Identifiable, Codable {
    let id: UUID
    var centerNodeText: String
    var nodes: [DraftNode]
    var connections: [DraftConnection]
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        centerNodeText: String,
        nodes: [DraftNode] = [],
        connections: [DraftConnection] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.centerNodeText = centerNodeText
        self.nodes = nodes
        self.connections = connections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DraftNode: Identifiable, Codable {
    let id: UUID
    var text: String
    var reason: String?
    var positionX: CGFloat
    var positionY: CGFloat
    var isCenter: Bool
    
    init(
        id: UUID = UUID(),
        text: String,
        reason: String? = nil,
        positionX: CGFloat,
        positionY: CGFloat,
        isCenter: Bool = false
    ) {
        self.id = id
        self.text = text
        self.reason = reason
        self.positionX = positionX
        self.positionY = positionY
        self.isCenter = isCenter
    }
}

struct DraftConnection: Identifiable, Codable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    
    init(id: UUID = UUID(), fromNodeId: UUID, toNodeId: UUID) {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
    }
}
