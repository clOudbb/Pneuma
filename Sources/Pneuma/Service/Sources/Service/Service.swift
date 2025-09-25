import Foundation

public protocol Service: Hashable, Identifiable, Sendable {

    func start()
    func stop()
}

public actor ServiceManager {

    @MainActor public static let shared = ServiceManager()

    private var services: [any Service] = []

    private let lock: os_unfair_lock_t

    private init() {
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }
}

public extension ServiceManager {

    func register<T: Service>(_ service: T) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        guard !services.contains(where: { $0 as! T == service }) else {
            return
        }
        services.append(service)
    }

    func unregister<T: Service>(_ service: T) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        services.removeAll { $0 as! T == service }
    }

    func service<T: Service>(of service: T) -> T? {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        guard let service = services.first(where: { $0 as? T == service }) as? T else {
            return nil
        }
        return service
    }

    func has<T: Service>(_ service: T) -> Bool {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        return services.contains(where: { $0 as? T == service })
    }

    func uninstall() {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        for service in services {
            service.stop()
        }
        services = []
    }
}

extension ServiceManager {

    public func start() {
        for service in services {
            service.start()
        }
    }

    public func stop() {
        for service in services {
            service.stop()
        }
    }
}
