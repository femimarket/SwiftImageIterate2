//
//  ProdApp.swift
//  Prod
//

import SwiftUI

@main
struct ProdApp: App {
    /// Demo bearer for the sample app. Real builds must source from Keychain
    /// or a server-issued session — never a literal in source.
    static let demoBearer = "019ec07a-c943-7275-b758-2315b8c9fa6f"

    var body: some Scene {
        WindowGroup {
            ContentView(bearer: Self.demoBearer)
        }
    }
}
