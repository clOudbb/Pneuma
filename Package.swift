// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pneuma",
//    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1),
        .macCatalyst(.v13)
    ],
    
    products: [
        .library(name: "Pneuma", targets: ["Pneuma"]),
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Env", targets: ["Env"]),
        .library(name: "Service", targets: ["Service"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "MVVM", targets: ["MVVM"]),

        .library(name: "YYCache", targets: ["YYCache"]),
        .library(name: "YYModel", targets: ["YYModel"]),
    ],

    dependencies: [
//      .package(name: "Network", path: "../Network"),
//      .package(url: "https://github.com/evgenyneu/keychain-swift", branch: "master"),
//      .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.3.0"),
        
        // MARK: - Vendors
        .package(url: "https://github.com/nicklockwood/LRUCache.git", .upToNextMinor(from: "1.1.2")),

        // MARK: - XCFramework
        .package(url: "https://github.com/onepiece-studio/mmkv.git", .upToNextMajor(from: "2.2.2")),
        
        // MARK: - Network
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.10.0")),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
//        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.4"),
        // MARK: - Layout
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        // MARK: - Router
        .package(url: "https://github.com/dimillian/AppRouter.git", from: "1.0.2"),
        .package(url: "https://github.com/devxoul/URLNavigator.git", .upToNextMajor(from: "2.5.1")),
        // MARK: - UI
        .package(url: "https://github.com/Dean151/ButtonKit.git", from: "0.6.1"), // SwiftUI
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", .upToNextMajor(from: "6.2.0")),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),
        // MARK: - Logger
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.9.0"),

        // MARK: - Auth
        .package(url: "https://github.com/trivago/Heimdallr.swift.git", .upToNextMajor(from: "4.0.0")),
//        .package(url: "https://github.com/OAuthSwift/OAuthSwift.git", .upToNextMajor(from: "2.2.0")),
//        .package(url: "https://github.com/openid/AppAuth-iOS.git", .upToNextMajor(from: "1.3.0")),
        // MARK: - Database
//        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4"),
//        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0") // SwiftUI-sqlitedata

        // MARK: - Charts
//        .package(url: "https://github.com/danielgindi/Charts.git", .upToNextMajor(from: "5.1.0")),

        // Objective-C
//        .package(url: "https://github.com:joeldev/JLRoutes.git", .upToNextMajor(from: "2.1.1")),
//        .package(url: "https://github.com/ccgus/fmdb", .upToNextMinor(from: "2.7.12")),

    ],
    
    targets: [
        .target(
            name: "Pneuma",
            dependencies: [
                .product(name: "MMKV", package: "mmkv"),
                .product(name: "Heimdallr", package: "Heimdallr.swift"),
                "Alamofire",
                "SDWebImageSwiftUI",
                "SnapKit",
                "AppRouter",
                "URLNavigator",
                "ButtonKit",
                "SFSafeSymbols",
                "Nuke",
                "CocoaLumberjack",
                
                "YYModel",
                "YYCache",
                "LRUCache",
                
                "Models",
                "Env",
                "Service",
                "Logger",
                "MVVM",
            ],
            path: "Sources/src",
        ),
        .testTarget(
            name: "PneumaTests",
            dependencies: ["Pneuma"]
        ),

        // MARK: - Vendors
        .target(
            name: "YYCache",
            path: "Sources/Vendors/YYCache/Sources/YYCache",
            publicHeadersPath: "."
        ),
        .target(
            name: "YYModel",
            path: "Sources/Vendors/YYModel/Sources/YYModel",
            publicHeadersPath: "."
        ),

        .target(
            name: "Models",
            dependencies: [
                 "YYModel"
            ],
            path: "Sources/Pneuma/Models/Sources/Models"
        ),
        .target(
            name: "Env",
            path: "Sources/Pneuma/Env/Sources/Env"
        ),

        // MARK: - Service
        .target(
            name: "Service",
            dependencies: [
                "Logger"
            ],
            path: "Sources/Pneuma/Service/Sources/Service"
        ),
        .target(
            name: "Logger",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
            ],
            path: "Sources/Pneuma/Logger/Sources/Logger"
        ),
        .target(
            name: "MVVM",
            path: "Sources/Pneuma/MVVM/Sources/MVVM"
        ),
    ]
)
