import Foundation

// MARK: - Service Identifier (RawRepresentable friendly)

/// Type-safe, Sendable service identifier wrapper.
/// Designed so you can use `enum MyServiceID: String` and construct `AnyServiceID(myEnum)`.
/// `AnyServiceID` is Hashable/Sendable and safe to use as dictionary keys inside actors.
public struct AnyServiceID: RawRepresentable, Hashable, Sendable {
    
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension AnyServiceID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}

// MARK: - Service Protocols

/// Services are reference types (classes) and therefore are actor-isolated by being stored
/// and managed inside `AppService` actor. We intentionally do NOT require `Service` to be
/// `Sendable` — that is difficult for arbitrary class-based services. Instead, `AppService`
/// provides actor-safe accessors and lifecycle methods; direct mutation of service state should
/// remain within the service instance and be synchronized by the service itself if needed.

public protocol Service: Sendable {
    /// Unique identifier for the service (used for lookup/register/remove)
    var id: AnyServiceID { get }

    /// Indicates whether the service is started
    var isRunning: Bool { get }

    /// Start the service asynchronously. Implementations must be safe to call multiple times.
    func start() async throws

    /// Stop the service asynchronously. Implementations must be safe to call multiple times.
    func stop() async throws

    /// Optional (synchronous) hook to inject dependencies.
    /// Keep this synchronous to avoid complicating registration paths; if you need async
    /// configuration, see the `AsyncConfigurableService` extension below.
    func configure(container: AppServiceContainer) async
}

public extension Service {
    
    func configure(container: AppServiceContainer) async { /* default no-op */ }
}

/// Optional protocol for services that want async configuration before start.
/// This is separate so most services stay simple and synchronous to register.
public protocol AsyncConfigurableService: Service {
    func configureAsync(container: AppServiceContainer) async
}

// MARK: - Factory / DI

public protocol ServiceFactory {
    func makeService() -> Service
}

/// A minimal actor-based container that allows services to resolve other services from
/// the manager safely. This container holds an unowned reference to the manager actor.
public actor AppServiceContainer {
    private unowned let manager: AppService
    init(manager: AppService) { self.manager = manager }

    /// Resolve service by id. Returns nil if it's not registered.
    public func resolve(id: AnyServiceID) async -> Service? {
        await manager.find(id: id)
    }
}

// MARK: - Plugins

/// Plugin contract for AppService plugin system. Plugins are class-based objects and
/// are installed/uninstalled from inside actor context — that keeps concurrency safe.
public protocol AppServicePlugin: Sendable {
    var pluginId: String { get }
    func install(on manager: AppService) async
    func uninstall(from manager: AppService) async
}

// MARK: - AppService actor

/// AppService: central registry & lifecycle manager for application services.
/// - Concurrency: actor-isolated state makes operations thread-safe. All service
///   registry mutations happen inside this actor.
public actor AppService {
    // Internal registry. Keys are AnyServiceID
    private var services: [AnyServiceID: Service] = [:]

    // Plugin manager is its own actor, but managed from this actor to keep sequencing clear.
    private let pluginManager: PluginManager

    // Container used for DI injection
    public lazy var container: AppServiceContainer = AppServiceContainer(manager: self)

    public init(plugins: [AppServicePlugin]?) async {
        self.pluginManager = PluginManager()
        
        if let plugins = plugins, !plugins.isEmpty {
            for plugin in plugins {
                await pluginManager.register(plugin: plugin, on: self)
            }
        }
    }

    // MARK: - Register / Remove / Find (single and batch)

    /// Register a single service. Returns previous service (if any) that was replaced.
    @discardableResult
    public func register(_ service: Service) async -> Service? {
        // Synchronous configure hook
        await service.configure(container: container)

        // If the service supports async configuration, call it here before making it discoverable.
        if let asyncService = service as? AsyncConfigurableService {
            await asyncService.configureAsync(container: container)
        }

        let previous = services.updateValue(service, forKey: service.id)
        await pluginManager.notifyServiceRegistered(service: service, previous: previous, on: self)
        return previous
    }

    /// Register via factory
    public func register(factory: ServiceFactory, replaceExisting: Bool = true) async -> Service {
        let s = factory.makeService()
        if !replaceExisting, let existing = services[s.id] { return existing }
        await register(s)
        return s
    }

    /// Batch register services. Accepts any Sequence of Service (Array, Set, etc.).
    /// Returns the list of replaced services (in insertion order of the sequence).
    @discardableResult
    public func register<S: Sequence>(_ newServices: S) async -> [Service] where S.Element == Service {
        var replaced: [Service] = []
        for s in newServices {
            if let prev = await register(s) {
                replaced.append(prev)
            }
        }
        return replaced
    }

    /// Remove a single service by id. Stops it before removal.
    @discardableResult
    public func remove(id: AnyServiceID) async -> Service? {
        guard let removed = services.removeValue(forKey: id) else { return nil }
        do {
            try await removed.stop()
        } catch {
            await pluginManager.notifyServiceError(service: removed, error: error)
        }
        await pluginManager.notifyServiceRemoved(service: removed, on: self)
        return removed
    }

    /// Batch remove services by ids. Accepts Array or Set of ids. Returns removed services.
    @discardableResult
    public func remove<ID: Sequence>(ids: ID) async -> [Service] where ID.Element == AnyServiceID {
        var removedList: [Service] = []
        for id in ids {
            if let removed = await remove(id: id) { removedList.append(removed) }
        }
        return removedList
    }

    /// Find a service by id (read-only). Returns the instance or nil.
    public func find(id: AnyServiceID) async -> Service? {
        services[id]
    }

    /// List all registered service ids
    public func allServiceIds() async -> [AnyServiceID] {
        Array(services.keys)
    }

    // MARK: - Lifecycle helpers

    /// Start a particular service by id
    public func start(id: AnyServiceID) async throws {
        guard let s = services[id] else { throw AppServiceError.serviceNotFound }
        try await s.start()
        await pluginManager.notifyServiceStarted(service: s, on: self)
    }

    /// Stop a particular service by id
    public func stop(id: AnyServiceID) async throws {
        guard let s = services[id] else { throw AppServiceError.serviceNotFound }
        try await s.stop()
        await pluginManager.notifyServiceStopped(service: s, on: self)
    }

    /// Gracefully stop all services
    public func stopAll() async {
        for (_, s) in services {
            do {
                try await s.stop()
            } catch {
                await pluginManager.notifyServiceError(service: s, error: error)
            }
        }
        services.removeAll()
    }

    // Expose plugin management for advanced use
    public func registerPlugin(_ plugin: AppServicePlugin) async {
        await pluginManager.register(plugin: plugin, on: self)
    }

    public func removePlugin(pluginId: String) async {
        await pluginManager.unregister(pluginId: pluginId, from: self)
    }
}

// MARK: - Errors

public enum AppServiceError: Error, LocalizedError {
    case serviceNotFound
    case serviceAlreadyRunning

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound: return "Service not found in AppService registry"
        case .serviceAlreadyRunning: return "Service is already running"
        }
    }
}

// MARK: - PluginManager (actor)

public actor PluginManager {
    private var pluginsById: [String: AppServicePlugin] = [:]

    func register(plugin: AppServicePlugin, on manager: AppService) async {
        guard pluginsById[plugin.pluginId] == nil else { return }
        pluginsById[plugin.pluginId] = plugin
        await plugin.install(on: manager)
    }

    func unregister(pluginId: String, from manager: AppService) async {
        guard let plugin = pluginsById.removeValue(forKey: pluginId) else { return }
        await plugin.uninstall(from: manager)
    }

    // Notification helpers invoked from AppService actor
    func notifyServiceRegistered(service: Service, previous: Service?, on manager: AppService) async {
        for plugin in pluginsById.values { await pluginDidRegister(plugin: plugin, service: service, previous: previous, on: manager) }
    }

    func notifyServiceRemoved(service: Service, on manager: AppService) async {
        for plugin in pluginsById.values { await pluginDidRemove(plugin: plugin, service: service, on: manager) }
    }

    func notifyServiceStarted(service: Service, on manager: AppService) async {
        for plugin in pluginsById.values { await pluginDidStart(plugin: plugin, service: service, on: manager) }
    }

    func notifyServiceStopped(service: Service, on manager: AppService) async {
        for plugin in pluginsById.values { await pluginDidStop(plugin: plugin, service: service, on: manager) }
    }

    func notifyServiceError(service: Service, error: Error) async {
        for plugin in pluginsById.values { await pluginDidError(plugin: plugin, service: service, error: error) }
    }

    private func pluginDidRegister(plugin: AppServicePlugin, service: Service, previous: Service?, on manager: AppService) async {
//        if let p = plugin as? LoggingPlugin {
//            p.log("Service registered: \(service.id.description)", level: .info, metadata: ["previous": previous?.id.description ?? "nil"])
//        }
    }

    private func pluginDidRemove(plugin: AppServicePlugin, service: Service, on manager: AppService) async {

    }

    private func pluginDidStart(plugin: AppServicePlugin, service: Service, on manager: AppService) async {
        
    }

    private func pluginDidStop(plugin: AppServicePlugin, service: Service, on manager: AppService) async {
        
    }

    private func pluginDidError(plugin: AppServicePlugin, service: Service, error: Error) async {
        
    }
}
