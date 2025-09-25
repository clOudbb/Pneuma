import Foundation
import Logging
import os // 导入 os 模块以使用最新的 OSLog.Logger API

/// 一个遵循 LogHandler 协议的结构体，它将日志消息直接桥接到 Apple 的统一日志系统。
/// 这个实现使用了 iOS 14 / macOS 11 及以上版本中引入的现代 `os.Logger` API。
@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public struct OSLogHandler: LogHandler, Sendable {
    
    /// os.Logger 实例，负责处理实际的日志记录。
    private let logger: os.Logger
    
    /// Handler 级别的日志元数据。
    private var storedMetadata: Logger.Metadata
    
    /// Handler 的最低日志级别。
    public var logLevel: Logger.Level

    public init(subsystem: String, category: String) {
        // 使用给定的 subsystem 和 category 创建一个 os.Logger 实例
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.storedMetadata = [:]
        self.logLevel = .info // 默认日志级别
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
        // 1. 合并元数据：将 handler 级别的元数据与单条日志的元数据合并
        let effectiveMetadata = self.storedMetadata.merging(metadata ?? [:], uniquingKeysWith: { _, new in new })
        
        // 2. 将 swift-log 的日志级别映射到 OSLogType
        let osLogType = level.toOSLogType()
        
        // 3. 构建最终的日志消息字符串
        // 为了充分利用 OSLog 的性能，我们只在需要时才构建元数据字符串
        var finalMessage: String = message.description
        if !effectiveMetadata.isEmpty {
            // 将元数据转换为 "[key1=value1 key2=value2]" 格式
            let metadataString = effectiveMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            finalMessage.append(" [\(metadataString)]")
        }

        // 4. 使用 os.Logger 记录日志
        // `os.Logger` 的 log 方法接受字符串插值，这在性能上是优化的。
        // 它只在日志级别被启用时，才会对参数进行序列化。
        self.logger.log(level: osLogType, "\(finalMessage)")
    }
    
    // MARK: - LogHandler 协议要求的元数据处理
    
    public var metadata: Logger.Metadata {
        get { self.storedMetadata }
        set { self.storedMetadata = newValue }
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { self.storedMetadata[metadataKey] }
        set { self.storedMetadata[metadataKey] = newValue }
    }
}

// MARK: - 日志级别映射
/// 将 swift-log 的 Logger.Level 映射到 OSLog 的 OSLogType
fileprivate extension Logger.Level {
    func toOSLogType() -> OSLogType {
        switch self {
        case .trace:
            // OSLog 没有 trace 级别, 映射到 debug
            return .debug
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            // OSLog 没有 notice 级别, 映射到 info
            return .info
        case .warning:
            // OSLog 没有 warning 级别, 映射到 default
            return .default
        case .error:
            return .error
        case .critical:
            // critical 级别应映射到 fault, 表示严重系统级错误
            return .fault
        }
    }
}
