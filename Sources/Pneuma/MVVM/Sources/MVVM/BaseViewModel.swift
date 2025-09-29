import Foundation
import Foundation

// MARK: - 1. BaseListViewModel: 内置了ViewState的基类

/// 一个通用的、可复用的列表ViewModel基类，内置了UDF架构的核心逻辑。
@Observable
@MainActor
open class BaseViewModel<Item: Identifiable & Equatable, Action> {

    public enum ViewState: Equatable {
        case idle
        case loading
        case success(data: [Item])
        case failure(Error)
        
        public static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case let (.success(lhsData), .success(rhsData)): return lhsData == rhsData
            case let (.failure(lhsError), .failure(rhsError)): return lhsError.localizedDescription == rhsError.localizedDescription
            default: return false
            }
        }
    }
    
    // MARK: - Properties (State)
    
    /// 当前页面的状态，是驱动UI的唯一来源。
    public private(set) var state: ViewState = .idle
    
    // MARK: - Public Interface
    
    open func send(_ action: Action) {
        // 由子类提供实现
    }
    
    // MARK: - Core Logic
    
    public func loadData() async {
        guard state != .loading else { return }
        
        self.state = .loading
        
        do {
            let items = try await fetchItems()
            self.state = .success(data: items)
        } catch {
            self.state = .failure(error)
        }
    }
    
    // MARK: - For Subclassing
    
    open func fetchItems() async throws -> [Item] {
        fatalError("Subclasses must implement `fetchItems()`.")
    }
}
