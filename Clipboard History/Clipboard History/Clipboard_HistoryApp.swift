//
//  Clipboard_HistoryApp.swift
//  Clipboard History
//
//  Created by Gurgen Abagyan on 04.05.26.
//

import SwiftUI

@main
struct Clipboard_HistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}
