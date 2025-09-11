import XCTest
@testable import gemini_swfit

class JSONSchemaGeneratorTests: XCTestCase {
    
    func testGenerateSchemaForUser() {
        // Given - Create instance directly
        let user = User(id: 1, name: "John", email: "john@example.com", addresses: [Address(street: "123 Main St", city: "New York")])
        
        // When
        let schema = schemaFor(user)
        
        // Then
        XCTAssertEqual(schema["type"] as? String, "object")
        let properties = schema["properties"] as? [String: [String: Any]]
        XCTAssertNotNil(properties)
        
        // Check required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required?.sorted(), ["id", "name", "addresses"].sorted())
        
        // Check property types
        XCTAssertEqual(properties?["id"]?["type"] as? String, "integer")
        XCTAssertEqual(properties?["name"]?["type"] as? String, "string")
        XCTAssertEqual(properties?["email"]?["type"] as? String, "string")
        
        // Check nested array structure
        let addresses = properties?["addresses"] as? [String: Any]
        XCTAssertEqual(addresses?["type"] as? String, "array")
        XCTAssertNotNil(addresses?["items"])
    }
    
    func testGenerateSchemaForAddress() {
        // Given
        let address = Address(street: "123 Main St", city: "New York")
        
        // When
        let schema = schemaFor(address)
        
        // Then
        XCTAssertEqual(schema["type"] as? String, "object")
        let properties = schema["properties"] as? [String: [String: Any]]
        XCTAssertNotNil(properties)
        
        // Check all properties are required (no optionals)
        let required = schema["required"] as? [String]
        XCTAssertEqual(required?.sorted(), ["street", "city"].sorted())
    }
    
    func testOptionalFieldsAreNotRequired() {
        // Given - User with nil email
        let user = User(id: 1, name: "John", email: nil, addresses: [])
        
        // When
        let schema = schemaFor(user)
        
        // Then
        let required = schema["required"] as? [String]
        XCTAssertFalse(required?.contains("email") ?? true)
    }
    
    func testBasicTypesMapping() {
        // Given
        struct BasicTypes {
            let stringValue: String
            let intValue: Int
            let doubleValue: Double
            let boolValue: Bool
        }
        
        let instance = BasicTypes(stringValue: "test", intValue: 42, doubleValue: 3.14, boolValue: true)
        
        // When
        let schema = schemaFor(instance)
        let properties = schema["properties"] as? [String: [String: Any]]
        
        // Then
        XCTAssertEqual(properties?["stringValue"]?["type"] as? String, "string")
        XCTAssertEqual(properties?["intValue"]?["type"] as? String, "integer")
        XCTAssertEqual(properties?["doubleValue"]?["type"] as? String, "number")
        XCTAssertEqual(properties?["boolValue"]?["type"] as? String, "boolean")
    }
    
    func testSchemaGenerationFailsForNonDefaultInit() {
        // When & Then
        XCTAssertThrowsError(try generateJSONSchemaWithThrow(for: NoDefaultInit.self))
    }
    
    func testLoggingOutput() {
        // When - This will log the JSON schema
        let schema = generateJSONSchema(for: TestStruct.self, defaultInstance: TestStruct())
        
        // Then
        XCTAssertNotNil(schema)
    }
    
    func testGenerateJSONSchemaWithLogging() {
        // When & Then - This will log the JSON schema to console
        let schema = generateJSONSchema(for: LogExample.self, defaultInstance: LogExample())
        XCTAssertNotNil(schema)
        print("✅ Schema generation and logging successful!")
    }
    
    func testComplexNestedStructSchema() {
        // Given - Complex nested structure
        struct GeoLocation: Codable {
            let latitude: Double
            let longitude: Double
            let altitude: Double?
            
            init(latitude: Double = 0.0, longitude: Double = 0.0, altitude: Double? = nil) {
                self.latitude = latitude
                self.longitude = longitude
                self.altitude = altitude
            }
        }
        
        struct ContactInfo: Codable {
            let email: String?
            let phone: String?
            let website: String?
            let social: [String: String]
            
            init(email: String? = nil, phone: String? = nil, website: String? = nil, social: [String: String] = [:]) {
                self.email = email
                self.phone = phone
                self.website = website
                self.social = social
            }
        }
        
        struct Review: Codable {
            let id: String
            let rating: Int
            let comment: String?
            let reviewer: String
            let date: String
            
            init(id: String = "", rating: Int = 0, comment: String? = nil, reviewer: String = "", date: String = "") {
                self.id = id
                self.rating = rating
                self.comment = comment
                self.reviewer = reviewer
                self.date = date
            }
        }
        
        struct ProductVariant: Codable {
            let id: String
            let name: String
            let sku: String
            let price: Double
            let available: Bool
            let attributes: [String: String]
            
            init(id: String = "", name: String = "", sku: String = "", price: Double = 0.0, available: Bool = false, attributes: [String: String] = [:]) {
                self.id = id
                self.name = name
                self.sku = sku
                self.price = price
                self.available = available
                self.attributes = attributes
            }
        }
        
        struct Product: Codable {
            let id: String
            let name: String
            let description: String?
            let category: String
            let tags: [String]
            let price: Double
            let inStock: Bool
            let location: GeoLocation
            let contact: ContactInfo
            let reviews: [Review]
            let variants: [ProductVariant]
            let metadata: [String: String]
            let createdAt: String
            let updatedAt: String?
            
            init(id: String = "", name: String = "", description: String? = nil, category: String = "", tags: [String] = [], price: Double = 0.0, inStock: Bool = false, location: GeoLocation = GeoLocation(), contact: ContactInfo = ContactInfo(), reviews: [Review] = [], variants: [ProductVariant] = [], metadata: [String: String] = [:], createdAt: String = "", updatedAt: String? = nil) {
                self.id = id
                self.name = name
                self.description = description
                self.category = category
                self.tags = tags
                self.price = price
                self.inStock = inStock
                self.location = location
                self.contact = contact
                self.reviews = reviews
                self.variants = variants
                self.metadata = metadata
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }
        
        struct Order: Codable {
            let id: String
            let customer: Customer
            let items: [OrderItem]
            let total: Double
            let status: OrderStatus
            let shippingAddress: Address
            let billingAddress: Address?
            let payment: PaymentInfo
            let notes: [String]?
            let createdAt: String
            
            enum OrderStatus: String, Codable {
                case pending = "pending"
                case confirmed = "confirmed"
                case shipped = "shipped"
                case delivered = "delivered"
                case cancelled = "cancelled"
            }
            
            struct Customer: Codable {
                let id: String
                let name: String
                let email: String
                let phone: String?
                let isVIP: Bool
                let addresses: [Address]
                
                init(id: String = "", name: String = "", email: String = "", phone: String? = nil, isVIP: Bool = false, addresses: [Address] = []) {
                    self.id = id
                    self.name = name
                    self.email = email
                    self.phone = phone
                    self.isVIP = isVIP
                    self.addresses = addresses
                }
            }
            
            struct OrderItem: Codable {
                let productId: String
                let quantity: Int
                let price: Double
                let discount: Double?
                let options: [String: String]
                
                init(productId: String = "", quantity: Int = 0, price: Double = 0.0, discount: Double? = nil, options: [String: String] = [:]) {
                    self.productId = productId
                    self.quantity = quantity
                    self.price = price
                    self.discount = discount
                    self.options = options
                }
            }
            
            struct PaymentInfo: Codable {
                let method: String
                let last4: String?
                let transactionId: String
                let amount: Double
                let currency: String
                let refunded: Bool
                let refundAmount: Double?
                
                init(method: String = "", last4: String? = nil, transactionId: String = "", amount: Double = 0.0, currency: String = "", refunded: Bool = false, refundAmount: Double? = nil) {
                    self.method = method
                    self.last4 = last4
                    self.transactionId = transactionId
                    self.amount = amount
                    self.currency = currency
                    self.refunded = refunded
                    self.refundAmount = refundAmount
                }
            }
            
            init(id: String = "", customer: Customer = Customer(), items: [OrderItem] = [], total: Double = 0.0, status: OrderStatus = .pending, shippingAddress: Address = Address(), billingAddress: Address? = nil, payment: PaymentInfo = PaymentInfo(), notes: [String]? = nil, createdAt: String = "") {
                self.id = id
                self.customer = customer
                self.items = items
                self.total = total
                self.status = status
                self.shippingAddress = shippingAddress
                self.billingAddress = billingAddress
                self.payment = payment
                self.notes = notes
                self.createdAt = createdAt
            }
        }
        
        // When - Create an instance and generate schema for the complex Order struct
        let order = Order(
            id: "ORD-12345",
            customer: Order.Customer(
                id: "CUST-67890",
                name: "John Doe",
                email: "john@example.com",
                phone: "+1-555-0123",
                isVIP: true,
                addresses: [
                    Address(street: "123 Main St", city: "New York"),
                    Address(street: "456 Oak Ave", city: "Boston")
                ]
            ),
            items: [
                Order.OrderItem(
                    productId: "PROD-001",
                    quantity: 2,
                    price: 29.99,
                    discount: 5.0,
                    options: ["color": "blue", "size": "large"]
                ),
                Order.OrderItem(
                    productId: "PROD-002",
                    quantity: 1,
                    price: 49.99,
                    discount: nil,
                    options: ["color": "red", "size": "medium"]
                )
            ],
            total: 104.97,
            status: .confirmed,
            shippingAddress: Address(street: "123 Main St", city: "New York"),
            billingAddress: Address(street: "123 Main St", city: "New York"),
            payment: Order.PaymentInfo(
                method: "credit_card",
                last4: "4242",
                transactionId: "TXN-98765",
                amount: 104.97,
                currency: "USD",
                refunded: false,
                refundAmount: nil
            ),
            notes: ["Please deliver between 9-5 PM", "Handle with care"],
            createdAt: "2024-01-15T10:30:00Z"
        )
        
        let schema = schemaFor(order)
        
        // Then - Verify the schema structure
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema["type"] as? String, "object")
        
        let properties = schema["properties"] as? [String: [String: Any]]
        XCTAssertNotNil(properties)
        
        // Check top-level required fields
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required)
        XCTAssertTrue(required?.contains("id") ?? false)
        XCTAssertTrue(required?.contains("customer") ?? false)
        XCTAssertTrue(required?.contains("items") ?? false)
        XCTAssertFalse(required?.contains("billingAddress") ?? true) // Should be optional
        
        // Check nested object structure
        let customerProp = properties?["customer"] as? [String: Any]
        XCTAssertEqual(customerProp?["type"] as? String, "object")
        
        // Check array structure
        let itemsProp = properties?["items"] as? [String: Any]
        XCTAssertEqual(itemsProp?["type"] as? String, "array")
        XCTAssertNotNil(itemsProp?["items"])
        
        // Check enum handling
        let statusProp = properties?["status"] as? [String: Any]
        XCTAssertEqual(statusProp?["type"] as? String, "string")
        
        print("✅ Complex nested struct schema generation successful!")
        
        // Log the full schema
        logSchemaJSON(schema, for: "Order")
    }
}

// Helper function to test throwing behavior
private func generateJSONSchemaWithThrow<T: Codable>(for type: T.Type) throws -> [String: Any] {
    return try generateJSONSchema(for: type)
}