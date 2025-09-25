// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Logging
import CocoaLumberjackSwift  // 来自 CocoaLumberjack，支持 DDLogHandler
import OSLog  // 系统 OSLog

public typealias Logger = Logging.Logger

/// 一个可发送的 LogHandler，它将日志消息分派给多个底层的 LogHandler。
/// A Sendable LogHandler that dispatches log messages to multiple underlying handlers.
public struct MultiplexLogHandler: LogHandler, Sendable {
    private var handlers: [any LogHandler & Sendable]
    
    public init(_ handlers: [any LogHandler & Sendable]) {
        self.handlers = handlers
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
        for handler in handlers {
            handler.log(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        }
    }
    
    public var metadata: Logger.Metadata {
        get {
            // 合并所有 handlers 的 metadata，后面的会覆盖前面的
            handlers.reduce(into: [:]) { $0.merge($1.metadata, uniquingKeysWith: { _, new in new }) }
        }
        set {
            for i in 0 ..< handlers.count {
                handlers[i].metadata = newValue
            }
        }
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            // 返回第一个 handler 中找到的值
            for handler in handlers {
                if let value = handler[metadataKey: metadataKey] {
                    return value
                }
            }
            return nil
        }
        set {
            for i in 0 ..< handlers.count {
                handlers[i][metadataKey: metadataKey] = newValue
            }
        }
    }

    public var logLevel: Logger.Level {
        get {
            // 返回所有 handlers 中最宽松（verbose）的级别
            handlers.map(\.logLevel).min() ?? .trace
        }
        set {
            for i in 0 ..< handlers.count {
                handlers[i].logLevel = newValue
            }
        }
    }
}

/// 管理和配置 App 日志系统的 Actor。
/// 这是一个单例，用于添加、删除和引导（bootstrap）日志处理后端。
public actor LoggerManager {
    
    /// 单例实例
    public static let shared = LoggerManager()

    /// 用于标识一个日志目标的结构体
    private struct LogDestination {
        let id: String
        let handler: any LogHandler & Sendable // <-- 核心约束
    }
    
    private var destinations: [LogDestination] = []
    
    // 私有化构造器以强制使用单例
    private init() {}
    
}

// MARK: - Public Configuration Methods
extension LoggerManager {

    /// 添加一个新的日志处理后端。
    /// - Parameters:
    ///   - handler: 要添加的 `LogHandler`。
    ///   - id: 一个唯一的字符串 ID，用于之后可以移除它。
    public func addHandler(_ handler: any LogHandler & Sendable, withID id: String) {
        // 移除任何已存在的同名 ID，防止重复添加
        destinations.removeAll { $0.id == id }
        destinations.append(LogDestination(id: id, handler: handler))
        debugPrint("LoggerManager: Added log handler with id '\(id)'.")
    }
    
    /// 根据 ID 移除一个日志处理后端。
    /// - Parameter id: 要移除的 handler 的 ID。
    public func removeHandler(withID id: String) {
        let initialCount = destinations.count
        destinations.removeAll { $0.id == id }
        if destinations.count < initialCount {
            debugPrint("LoggerManager: Removed log handler with id '\(id)'.")
        }
    }
    
    /// 使用当前所有已添加的 handlers 配置全局的 `LoggingSystem`。
    /// 这个方法应该在 App 启动时调用一次。
    public func bootstrap() {
        // 1. 在 actor 的隔离环境中，安全地准备一个不可变的、Sendable 的“快照”。
        let aggregateHandler: any LogHandler & Sendable
        
        let handlers = self.destinations.map { $0.handler }
        
        if handlers.isEmpty {
            debugPrint("LoggerManager Warning: Bootstrapping with no handlers. Using default stderr logger.")
            aggregateHandler = StreamLogHandler.standardError(label: "default")
        } else if handlers.count == 1 {
            aggregateHandler = handlers[0]
        } else {
            aggregateHandler = MultiplexLogHandler(handlers)
        }

        // 2. 调用全局函数，并传递一个标记为 @Sendable 的闭包。
        // 这个闭包只捕获了上面的 `aggregateHandler` 常量，它是一个 Sendable 值。
        // 因此，这个闭包本身也是 Sendable 的，可以安全地传递出 actor 的作用域。
        LoggingSystem.bootstrap { @Sendable _ in
            return aggregateHandler
        }
        
        debugPrint("✅ Logging system bootstrapped successfully from within the actor.")
    }

    
    // MARK: - Convenience Methods for Common Loggers

    /// 便捷方法：添加 OSLog handler。
    public func addOSLogHandler(subsystem: String, category: String = "Default", id: String = "oslog") {
        addHandler(OSLogHandler(subsystem: subsystem, category: category), withID: id)
    }
    
    /// 便捷方法：添加 CocoaLumberjack handler。
    /// **注意**: 调用此方法前，必须先配置好 CocoaLumberjack 本身。
    public func addLumberjackHandler(id: String = "lumberjack") {
        addHandler(LumberjackLogHandler(), withID: id)
    }

    // MARK: - Logger Creation
    
    /// 创建一个 Logger 实例。这个方法是非 actor-isolated 的，
    /// 意味着它可以从任何地方被同步调用，无需 `await`。
    nonisolated public func makeLogger(label: String) -> Logger {
        return Logger(label: label)
    }
}
