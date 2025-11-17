//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/9/22.
//

import Logger
import Foundation

public typealias AnyLogService = any LogService

public enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol LogService: Service {
    
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt) async
}

extension LogService {

    public func log(level: LogLevel, message: String, file: String = #file, function: String = #function, line: UInt = #line) async {

    }
}

public actor LogServiceImpl {

    private let logger = LoggerManager.shared
    
    init() {
        Task {
            await configureLogging()
        }
    }

    private func configureLogging() async {
        let loggerManager = LoggerManager.shared
        
        await loggerManager.addLumberjackHandler()
        
        let subsystem = Bundle.main.bundleIdentifier ?? "com.pneuma.oslog.subsystem"
        await loggerManager.addOSLogHandler(subsystem: subsystem, category: "AppLifecycle")
        await loggerManager.bootstrap()
        
        let logger = loggerManager.makeLogger(label: .defaultLoggerIdentifier)
        logger.info("Official OSLogHandler configured and ready.")
    }
}

extension AnyServiceID {
    
    static let logService = AnyServiceID("com.service.logservice")
}

extension LogServiceImpl: LogService {

    nonisolated public var id: AnyServiceID {
        .logService
    }
    
    nonisolated public var isRunning: Bool {
        true
    }
    
    public func log(level: LogLevel, message: String, file: String, function: String, line: UInt) async {
        
    }
    
    public func start() async throws {
        
    }
    
    public func stop() async throws {
        
    }
}

private extension String {

    static let defaultLoggerIdentifier = "com.logger.service"
}
