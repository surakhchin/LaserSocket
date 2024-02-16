//
//  AppDelegate.swift
//  LaserSocket
//
//  Created by Sergey Urakhchin on 2/9/24.
//

import UIKit
import SwiftUI
import SocketIO

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Your SocketConnection setup
        let socketConnection = SocketConnection.shared
        socketConnection.socket.connect()

        // SwiftUI setup
        let contentView = ContentView().environmentObject(socketConnection)

        // Use a UIHostingController as the window root view controller.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()

        return true
    }
}
