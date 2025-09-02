// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    // 包的名称
    name: "{{PACKAGE_NAME}}",

    // 支持的平台及最低版本
    platforms: [
        .iOS(.v16),           // 支持 iOS 16 及以上（Swift 6.0 要求较高版本）
        .macOS(.v13),         // 支持 macOS 13 及以上
        .tvOS(.v16),          // 支持 tvOS 16 及以上
        .watchOS(.v9),        // 支持 watchOS 9 及以上
        .visionOS(.v2),       // 支持 visionOS 2 及以上
        // 可根据需要添加或移除平台
    ],

    // 包的产品（可执行文件或库）
    products: [
        // 动态/静态库
        .library(
            name: "{{LIBRARY_NAME}}",
            type: .dynamic, // 或 .static，或省略以让消费者决定
            targets: ["{{TARGET_NAME}}"]
        ),
        // 可执行程序
        .executable(
            name: "{{EXECUTABLE_NAME}}",
            targets: ["{{EXECUTABLE_TARGET_NAME}}"]
        ),
    ],

    // 包的依赖
    dependencies: [
        // 示例：远程 Swift 包
        .package(
            url: "https://github.com/example/example-package.git",
            from: "1.0.0"
        ),
        // 示例：特定分支或提交
        .package(
            url: "https://github.com/example/another-package.git",
            branch: "main"
        ),
        // 示例：本地包
        .package(path: "../LocalPackage"),
        // 可根据需要添加更多依赖
    ],

    // 目标（模块）
    targets: [
        // 主目标（库或模块）
        .target(
            name: "{{TARGET_NAME}}",
            dependencies: [
                // 引用依赖包中的产品
                .product(name: "ExampleProduct", package: "example-package"),
                // 引用其他目标
                "{{ANOTHER_TARGET_NAME}}"
            ],
            path: "Sources/{{TARGET_NAME}}", // 自定义源文件路径
            exclude: ["Sources/{{TARGET_NAME}}/Deprecated"], // 排除的文件
            sources: ["Sources/{{TARGET_NAME}}/Core"], // 指定包含的源文件
            publicHeadersPath: "Sources/{{TARGET_NAME}}/Public", // C/C++ 头文件路径
            swiftSettings: [
                // Swift 6.0 编译设置
                .define("DEBUG", .when(configuration: .debug)),
                .enableExperimentalFeature("StrictConcurrency"), // Swift 6.0 强调并发安全
                .enableUpcomingFeature("FullTypedThrows"), // Swift 6.0 新特性
                .unsafeFlags(["-strict-concurrency=complete"]) // 强制完整并发检查
            ],
            linkerSettings: [
                // 链接器设置
                .linkedFramework("Foundation"),
                .linkedLibrary("z"),
                .unsafeFlags(["-L", "/usr/local/lib"])
            ]
        ),

        // 可执行目标
        .executableTarget(
            name: "{{EXECUTABLE_TARGET_NAME}}",
            dependencies: ["{{TARGET_NAME}}"],
            path: "Sources/{{EXECUTABLE_TARGET_NAME}}",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .enableUpcomingFeature("FullTypedThrows")
            ]
        ),

        // 测试目标
        .testTarget(
            name: "{{TARGET_NAME}}Tests",
            dependencies: ["{{TARGET_NAME}}"],
            path: "Tests/{{TARGET_NAME}}Tests",
            exclude: ["Tests/{{TARGET_NAME}}Tests/Fixtures"],
            sources: ["Tests/{{TARGET_NAME}}Tests"],
            resources: [
                // 测试资源
                .process("Resources"), // 自动处理资源目录
                .copy("Fixtures/data.json") // 复制特定资源
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("FullTypedThrows")
            ]
        ),

        // 二进制目标（XCFramework 或二进制文件）
        .binaryTarget(
            name: "{{BINARY_TARGET_NAME}}",
            path: "Frameworks/{{BINARY_TARGET_NAME}}.xcframework"
            // 或者使用 URL 下载
            // url: "https://example.com/{{BINARY_TARGET_NAME}}.xcframework.zip",
            // checksum: "abc123..."
        ),

        // 插件目标（Swift 插件）
        .plugin(
            name: "{{PLUGIN_NAME}}",
            capability: .buildTool(), // 或 .command(...)
            dependencies: ["{{TARGET_NAME}}"],
            path: "Plugins/{{PLUGIN_NAME}}"
        ),
    ],

    // Swift 语言版本
    swiftLanguageVersions: [.v6],

    // C/C++ 设置
    cLanguageStandard: .c17, // Swift 6.0 支持更新的 C 标准
    cxxLanguageStandard: .cxx20 // 支持 C++20
)
