//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/9/22.
//

import Logger
import Foundation

public actor LogService {
    
    public let id = "com.pneuma.logging.service"

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

extension LogService: Service {

    nonisolated public func start() {
        
    }
    
    nonisolated public func stop () {

    }

    public static func == (lhs: LogService, rhs: LogService) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension String {

    static let defaultLoggerIdentifier = "com.pneuma.logger"
}
