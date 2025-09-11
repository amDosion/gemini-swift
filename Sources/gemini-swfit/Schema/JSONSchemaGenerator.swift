import Foundation

// MARK: - Schema Errors

public enum JSONSchemaError: Error {
    case cannotCreateInstance
}

// MARK: - JSON Schema Generation

// Generate schema from Codable type
public func generateJSONSchema<T: Codable>(for type: T.Type) throws -> [String: Any] {
    // Try to create a default instance first
    if let defaultInstance = createDefaultInstance(of: type) {
        let schema = schemaFor(defaultInstance)
        logSchemaJSON(schema, for: String(describing: type))
        return schema
    }
    
    // Fallback: generate schema from type information
    let schema = try generateSchemaFromCodableType(type)
    logSchemaJSON(schema, for: String(describing: type))
    return schema
}

// Generate schema from Codable type with provided default instance
public func generateJSONSchema<T: Codable>(for type: T.Type, defaultInstance: T) -> [String: Any] {
    let schema = schemaFor(defaultInstance)
    logSchemaJSON(schema, for: String(describing: type))
    return schema
}

// Helper function to log schema as JSON
public func logSchemaJSON(_ schema: [String: Any], for typeName: String) {
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys])
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\n=== JSON Schema for \(typeName) ===")
            print(jsonString)
            print("=== End Schema ===\n")
        }
    } catch {
        print("Failed to serialize schema to JSON: \(error)")
    }
}

// MARK: - Private Helpers

// Helper to create default instance for Codable types
private func createDefaultInstance<T: Codable>(of type: T.Type) -> T? {
    // Check if type provides a default instance through SchemaDefaultProvider
    if let providerType = type as? any SchemaDefaultProvider.Type {
        // This is a workaround - we can't directly cast to T.Type here
        // In a real implementation, you'd use more advanced reflection
        return nil
    }
    
    // Try with empty JSON first
    if let instance = try? JSONDecoder().decode(T.self, from: "{}".data(using: .utf8)!) {
        return instance
    }
    
    // For simple structs, try to create instance with default values
    return createInstanceWithDefaults(type)
}

// Create instance with default values for simple structs
private func createInstanceWithDefaults<T: Codable>(_ type: T.Type) -> T? {
    // This is a generic approach that works for simple structs
    // For complex structs, users should provide a default initializer
    _ = String(describing: type)
    
    // Try to create instance through reflection (limited capability in Swift)
    // This is a best-effort approach
    return nil
}

// Generate schema from Codable type without creating an instance
private func generateSchemaFromCodableType<T: Codable>(_ type: T.Type) throws -> [String: Any] {
    // This is a fallback method when no default instance can be created
    // In a real implementation, you could use more sophisticated reflection
    // or require users to provide a default instance
    throw JSONSchemaError.cannotCreateInstance
}

// MARK: - Recursive Schema Generation

// Recursive schema generation
public func schemaFor(_ value: Any) -> [String: Any] {
    let mirror = Mirror(reflecting: value)
    
    switch mirror.displayStyle {
    case .optional:
        if let first = mirror.children.first {
            return schemaFor(first.value)
        } else {
            return ["type": "null"]
        }
        
    case .struct, .class:
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for child in mirror.children {
            guard let key = child.label else { continue }
            properties[key] = schemaFor(child.value)
            
            // If not Optional, add to required
            let childMirror = Mirror(reflecting: child.value)
            if childMirror.displayStyle != .optional {
                required.append(key)
            }
        }
        
        return [
            "type": "object",
            "properties": properties,
            "required": required
        ]
        
    case .collection:
        if let first = mirror.children.first {
            return [
                "type": "array",
                "items": schemaFor(first.value)
            ]
        } else {
            return ["type": "array"]
        }
        
    case .dictionary:
        if let first = mirror.children.first,
           let pair = first.value as? (key: AnyHashable, value: Any) {
            return [
                "type": "object",
                "additionalProperties": schemaFor(pair.value)
            ]
        } else {
            return ["type": "object"]
        }
        
    case .enum:
        return ["type": "string"]
        
    default:
        // Basic type detection
        switch value {
        case is String: return ["type": "string"]
        case is Int, is Int8, is Int16, is Int32, is Int64: return ["type": "integer"]
        case is UInt, is UInt8, is UInt16, is UInt32, is UInt64: return ["type": "integer"]
        case is Double, is Float: return ["type": "number"]
        case is Bool: return ["type": "boolean"]
        default: return ["type": "string"]
        }
    }
}