//
//  File.swift
//  Pneuma
//
//  Created by 张征鸿 on 2025/9/30.
//

import Foundation

// 数据模型 (Model)
struct Product: Identifiable, Equatable, Codable {
    let id: Int
    let title: String
    let price: Double
}

// 模拟的网络服务 (Service)
struct ProductService {
    /// 模拟异步获取产品列表
    func fetchProducts() async throws -> [Product] {
        // 模拟1.5秒的网络延迟
        try await Task.sleep(for: .seconds(1.5))
        
        // 模拟成功或失败
        if Bool.random() {
            // 成功返回数据
            return [
                Product(id: 1, title: "Modern Laptop", price: 1200.0),
                Product(id: 2, title: "Wireless Mouse", price: 50.0),
                Product(id: 3, title: "Mechanical Keyboard", price: 150.0)
            ]
        } else {
            // 失败抛出错误
            throw URLError(.badServerResponse)
        }
    }
}

// 具体的ViewModel
@MainActor
final class ProductListViewModel: BaseViewModel<Product, ProductListViewModel.Action> {
    
    // 依赖注入，可以是真实的Service，也可以是Mock
    private let productService: ProductService

    init(productService: ProductService = ProductService()) {
        self.productService = productService
    }

    // 1. 定义此页面特有的Action
    enum Action {
        case onAppear
        case onRefresh
    }
    
    // 2. 实现send方法，将Action转化为具体的业务调用
    override func send(_ action: Action) {
        switch action {
        case .onAppear:
            // 首次进入页面时加载数据
            Task { await loadData() }
        case .onRefresh:
            // 下拉刷新时加载数据
            Task { await loadData() }
        }
    }
    
    // 3. 实现具体的数据获取逻辑
    override func fetchItems() async throws -> [Product] {
        return try await productService.fetchProducts()
    }
}
