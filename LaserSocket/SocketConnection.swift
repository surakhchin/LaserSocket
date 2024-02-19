//
//  SocketConnection.swift
//  LaserSocket
//
//  Created by Sergey Urakhchin on 2/9/24.
//

import Foundation
import SocketIO

class SocketConnection: ObservableObject {
    static let shared = SocketConnection()

    private let manager: SocketManager
    let socket: SocketIOClient

    private init() {
        manager = SocketManager(socketURL: URL(string: "https://lasertag.cc")!)
        self.socket = manager.defaultSocket

        setupSocketEvents()
    }

    // Add other methods or properties as needed

    private func setupSocketEvents() {
        // Handle socket connection event
        socket.on(clientEvent: .connect) { data, ack in
            print("Socket connected")
        }

        // Listen for "chat message" event from the server
        socket.on("chat message") { data, ack in
            print("Received chat message: \(data)")
        }

        // Listen for "load:coords" event from the server
        socket.on("laserSocketServer") { data, ack in
//            print("Received laserSocketServer: \(data)")
        }

        // Listen for "dynamic" event from the server
        socket.on("dynamic") { data, ack in
            print("Received dynamic: \(data)")
        }

        // You can add more event handlers here as needed
    }
}
