import Foundation

// Protocol for types that can provide a default instance for schema generation
public protocol SchemaDefaultProvider {
    static var schemaDefault: Self { get }
}