//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/9/24.
//

import Logging
import CocoaLumberjackSwift  // 来自 CocoaLumberjack，支持 DDLogHandler

// MARK: - CocoaLumberjack Bridge

/// 一个简单的 `LogHandler` 来桥接 `swift-log` 和 `CocoaLumberjack`。
/// **注意**: 社区有更完善的实现（如 `swift-log-lumberjack`），这里仅作示例。
struct LumberjackLogHandler: LogHandler, Sendable {

    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level = .trace

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
    
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let ddLogLevel = level.toDDLogLevel()
        let ddlogFlag = level.toDDLogFlag()
        
        // 合并 metadata，并格式化成字符串
        let allMetadata = (self.metadata).merging(metadata ?? [:], uniquingKeysWith: { _, new in new })
        let metadataString = allMetadata.isEmpty ? "" : " \(allMetadata.map { "\($0)=\($1)" }.joined(separator: " "))"
        
        let logMessage = "\(message)\(metadataString)"
        
        DDLog.log(
            asynchronous: true, // 推荐异步以提高性能
            level: ddLogLevel,
            flag: ddlogFlag,
            context: 0,
            file: file,
            function: function,
            line: line,
            tag: nil,
            format: "%@",
            arguments: getVaList([logMessage])
        )
    }
}

// 辅助扩展，将 swift-log 的 Level 映射到 CocoaLumberjack
fileprivate extension Logger.Level {

    func toDDLogLevel() -> DDLogLevel {
        switch self {
        case .trace:    return .verbose
        case .debug:    return .debug
        case .info:     return .info
        case .notice:   return .info // DDLog 没有 notice，映射到 info
        case .warning:  return .warning
        case .error:    return .error
        case .critical: return .error // DDLog 没有 critical，映射到 error
        }
    }
    
    func toDDLogFlag() -> DDLogFlag {
        switch self {
        case .trace:    return .verbose
        case .debug:    return .debug
        case .info:     return .info
        case .notice:   return .info
        case .warning:  return .warning
        case .error:    return .error
        case .critical: return .error
        }
    }
}
