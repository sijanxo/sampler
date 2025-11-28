//
//  samplerApp.swift
//  sampler
//
//  Created by Sijan Khadka on 27/11/2025.
//

import SwiftUI

@main
struct samplerApp: App {
    @StateObject private var padVM = PadViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(padVM)
        }
    }
}
