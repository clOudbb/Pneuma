//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/10/3.
//

import Foundation
import Observation

public struct PreferencesKeys {

    struct Appearance {
        static let isDarkModeEnabled = "preferences.appearance.isDarkModeEnabled"
        static let themeColorName = "preferences.appearance.themeColorName"
    }
    
    struct Account {
        static let username = "preferences.account.username"
        static let lastLoginDate = "preferences.account.lastLoginDate"
        static let isLoggedIn = "preferences.account.isLoggedIn"
    }
}

public actor AppPreferences {
    
    @MainActor static let shared = AppPreferences()

    @UserDefault(key: PreferencesKeys.Account.lastLoginDate, defaultValue: nil)
    var lastLoginDate: Date?
    
    @UserDefault(key: PreferencesKeys.Account.isLoggedIn, defaultValue: false)
    var isLoggedIn: Bool

    private init() {}
    
    func logout() {
        self.isLoggedIn = false
        self.lastLoginDate = nil
    }
}
