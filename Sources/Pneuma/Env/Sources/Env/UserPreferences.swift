import Combine
import Foundation
import SwiftUI

@MainActor
@Observable public class UserPreferences {
    
    class Storage {
        //    @AppStorage("preferred_browser") public var preferredBrowser: PreferredBrowser = .inAppSafari
        
        init() {
            
        }
        
    }
    
    public static let sharedDefault = UserDefaults(suiteName: "group.com.thomasricouard.IceCubesApp")
    public static let shared = UserPreferences()
    private let storage = Storage()
    
    private init() {
//        preferredBrowser = storage.preferredBrowser
    }
}

extension UInt: @retroactive RawRepresentable {
    public var rawValue: Int {
        Int(self)
    }
    
    public init?(rawValue: Int) {
        if rawValue >= 0 {
            self.init(rawValue)
        } else {
            return nil
        }
    }
}
