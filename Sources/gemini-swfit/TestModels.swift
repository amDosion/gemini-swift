import Foundation

// MARK: - Shared Test Models

/// Test address structure used across multiple test files
public struct Address: Codable, Equatable {
    public let street: String
    public let city: String
    
    public init(street: String = "", city: String = "") {
        self.street = street
        self.city = city
    }
}

/// Test user structure with optional email and addresses array
public struct User: Codable, Equatable {
    public let id: Int
    public let name: String
    public let email: String?
    public let addresses: [Address]
    
    public init(id: Int = 0, name: String = "", email: String? = nil, addresses: [Address] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.addresses = addresses
    }
}

/// Test product structure for e-commerce examples
public struct Product: Codable, Equatable {
    public let name: String
    public let price: Double
    public let inStock: Bool
    public let tags: [String]
    
    public init(name: String = "", price: Double = 0.0, inStock: Bool = false, tags: [String] = []) {
        self.name = name
        self.price = price
        self.inStock = inStock
        self.tags = tags
    }
}

/// Simple user with default values for schema generation tests
public struct SimpleUser: Codable, Equatable {
    public let id: Int
    public let name: String
    public let email: String?
    
    public init(id: Int = 0, name: String = "", email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
    }
}

/// Simple product with default values
public struct SimpleProduct: Codable, Equatable {
    public let name: String
    public let price: Double
    public let inStock: Bool
    
    public init(name: String = "", price: Double = 0.0, inStock: Bool = false) {
        self.name = name
        self.price = price
        self.inStock = inStock
    }
}

/// Struct without default initializer for error testing
public struct NoDefaultInit: Codable, Equatable {
    let value: String
    
    public init(value: String) {
        self.value = value
    }
}

/// Log example structure for testing
public struct LogExample: Codable, Equatable {
    public let id: Int
    public let title: String
    public let count: Int
    public let ratio: Double
    public let flag: Bool
    public let tags: [String]
    
    public init(id: Int = 0, title: String = "", count: Int = 0, ratio: Double = 0.0, flag: Bool = false, tags: [String] = []) {
        self.id = id
        self.title = title
        self.count = count
        self.ratio = ratio
        self.flag = flag
        self.tags = tags
    }
}

/// Basic test struct
public struct TestStruct: Codable, Equatable {
    public let id: Int
    public let name: String
    public let isActive: Bool
    public let score: Double
    
    public init(id: Int = 0, name: String = "", isActive: Bool = false, score: Double = 0.0) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.score = score
    }
}