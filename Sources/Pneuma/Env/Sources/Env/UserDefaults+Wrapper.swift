//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/10/3.
//

import Foundation

@propertyWrapper
public struct UserDefault<Value> {

    let key: String
    
    let defaultValue: Value

    private let container = UserDefaults.standard

    public var wrappedValue: Value {
        get {
            container.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}
