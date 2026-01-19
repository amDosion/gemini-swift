//
//  DocumentExtractor.swift
//  gemini-swfit
//
//  Agent for structured data extraction from documents
//

import Foundation
import SwiftyBeaver

/// Agent specialized in extracting structured data from documents
public final class DocumentExtractorAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Extraction configuration
    public struct ExtractionConfig: Sendable {
        public let extractionType: ExtractionType
        public let outputFormat: OutputFormat
        public let includeConfidence: Bool
        public let validateOutput: Bool

        public enum ExtractionType: String, Sendable {
            case entities = "Named Entities"
            case tables = "Tables and Data"
            case keyValuePairs = "Key-Value Pairs"
            case sections = "Document Sections"
            case summary = "Summary Extraction"
            case comprehensive = "Comprehensive"
        }

        public enum OutputFormat: String, Sendable {
            case json = "JSON"
            case markdown = "Markdown"
            case structured = "Structured Text"
        }

        public init(
            extractionType: ExtractionType = .comprehensive,
            outputFormat: OutputFormat = .json,
            includeConfidence: Bool = true,
            validateOutput: Bool = true
        ) {
            self.extractionType = extractionType
            self.outputFormat = outputFormat
            self.includeConfidence = includeConfidence
            self.validateOutput = validateOutput
        }
    }

    /// Extraction result
    public struct ExtractionResult: Sendable {
        public let entities: [Entity]
        public let keyValuePairs: [KeyValuePair]
        public let tables: [ExtractedTable]
        public let sections: [DocumentSection]
        public let metadata: DocumentMetadata
        public let confidence: Double

        public struct Entity: Sendable {
            public let type: EntityType
            public let value: String
            public let context: String
            public let confidence: Double

            public enum EntityType: String, Sendable {
                case person = "Person"
                case organization = "Organization"
                case location = "Location"
                case date = "Date"
                case money = "Money"
                case percentage = "Percentage"
                case product = "Product"
                case email = "Email"
                case phone = "Phone"
                case custom = "Custom"
            }
        }

        public struct KeyValuePair: Sendable {
            public let key: String
            public let value: String
            public let dataType: String
            public let confidence: Double
        }

        public struct ExtractedTable: Sendable {
            public let name: String
            public let headers: [String]
            public let rows: [[String]]
            public let rowCount: Int
        }

        public struct DocumentSection: Sendable {
            public let title: String
            public let content: String
            public let level: Int
            public let wordCount: Int
        }

        public struct DocumentMetadata: Sendable {
            public let documentType: String
            public let language: String
            public let wordCount: Int
            public let pageEstimate: Int
        }
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let config: ExtractionConfig

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Document Extractor",
        client: GeminiClient,
        config: ExtractionConfig = ExtractionConfig(),
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Extracts structured data from documents"
        self.capabilities = [.documentExtraction, .textGeneration]
        self.client = client
        self.config = config
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !input.content.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting document extraction")

        let result = try await extractFromDocument(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Extracted \(result.entities.count) entities, \(result.keyValuePairs.count) key-value pairs")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Extraction Methods

    private func extractFromDocument(input: AgentInput) async throws -> ExtractionResult {
        // Get document metadata first
        let metadata = analyzeDocumentMetadata(input.content)

        // Perform extraction based on config
        let prompt = buildExtractionPrompt(for: input, metadata: metadata)
        let response = try await generateWithLLM(prompt: prompt)

        return parseExtractionResult(response, metadata: metadata)
    }

    private func analyzeDocumentMetadata(_ content: String) -> ExtractionResult.DocumentMetadata {
        let words = content.split(separator: " ").count
        let pageEstimate = max(1, words / 300)

        // Simple language detection
        let language = detectLanguage(content)

        // Document type heuristics
        let documentType = detectDocumentType(content)

        return ExtractionResult.DocumentMetadata(
            documentType: documentType,
            language: language,
            wordCount: words,
            pageEstimate: pageEstimate
        )
    }

    private func detectLanguage(_ content: String) -> String {
        let chineseChars = content.filter { $0.unicodeScalars.first.map { CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}").contains($0) } ?? false }
        if Double(chineseChars.count) / Double(content.count) > 0.3 {
            return "Chinese"
        }
        return "English"
    }

    private func detectDocumentType(_ content: String) -> String {
        let contentLower = content.lowercased()

        if contentLower.contains("invoice") || contentLower.contains("bill") {
            return "Invoice"
        } else if contentLower.contains("contract") || contentLower.contains("agreement") {
            return "Contract"
        } else if contentLower.contains("report") {
            return "Report"
        } else if contentLower.contains("receipt") {
            return "Receipt"
        } else if contentLower.contains("resume") || contentLower.contains("cv") {
            return "Resume"
        }
        return "General Document"
    }

    private func buildExtractionPrompt(
        for input: AgentInput,
        metadata: ExtractionResult.DocumentMetadata
    ) -> String {
        return """
        Extract structured data from this \(metadata.documentType):

        Extraction Type: \(config.extractionType.rawValue)
        Output Format: \(config.outputFormat.rawValue)

        Document Content:
        \(input.content.prefix(10000))

        Extract the following:

        ENTITIES:
        List all named entities in format:
        - Type: [person/organization/location/date/money/percentage/product/email/phone] | Value: [extracted value] | Context: [surrounding text] | Confidence: [0.X]

        KEY_VALUE_PAIRS:
        List all key-value pairs in format:
        - Key: [field name] | Value: [field value] | DataType: [string/number/date/boolean] | Confidence: [0.X]

        TABLES:
        If tables exist, format as:
        TABLE: [Table Name]
        Headers: [Col1], [Col2], [Col3]
        Row: [Val1], [Val2], [Val3]
        Row: [Val1], [Val2], [Val3]

        SECTIONS:
        List document sections:
        - Level: [1/2/3] | Title: [Section title] | WordCount: [count]
          Content: [Brief content summary]

        OVERALL_CONFIDENCE: [0.X]
        """
    }

    private func parseExtractionResult(
        _ response: String,
        metadata: ExtractionResult.DocumentMetadata
    ) -> ExtractionResult {
        var entities: [ExtractionResult.Entity] = []
        var keyValuePairs: [ExtractionResult.KeyValuePair] = []
        var tables: [ExtractionResult.ExtractedTable] = []
        var sections: [ExtractionResult.DocumentSection] = []
        var confidence = 0.75

        // Parse ENTITIES
        if let range = response.range(of: "ENTITIES:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Type:") || trimmed.hasPrefix("-Type:") {
                    if let entity = parseEntity(trimmed) {
                        entities.append(entity)
                    }
                } else if trimmed.contains("KEY_VALUE_PAIRS:") {
                    break
                }
            }
        }

        // Parse KEY_VALUE_PAIRS
        if let range = response.range(of: "KEY_VALUE_PAIRS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Key:") || trimmed.hasPrefix("-Key:") {
                    if let kvp = parseKeyValuePair(trimmed) {
                        keyValuePairs.append(kvp)
                    }
                } else if trimmed.contains("TABLES:") {
                    break
                }
            }
        }

        // Parse TABLES
        if let range = response.range(of: "TABLES:") {
            let after = String(response[range.upperBound...])
            tables = parseTables(after)
        }

        // Parse SECTIONS
        if let range = response.range(of: "SECTIONS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            var currentSection: (level: Int, title: String, wordCount: Int)? = nil

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Level:") {
                    if let section = parseSectionHeader(trimmed) {
                        currentSection = section
                    }
                } else if trimmed.hasPrefix("Content:") && currentSection != nil {
                    let content = trimmed.replacingOccurrences(of: "Content:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    sections.append(ExtractionResult.DocumentSection(
                        title: currentSection!.title,
                        content: content,
                        level: currentSection!.level,
                        wordCount: currentSection!.wordCount
                    ))
                    currentSection = nil
                } else if trimmed.contains("OVERALL_CONFIDENCE:") {
                    break
                }
            }
        }

        // Parse OVERALL_CONFIDENCE
        if let range = response.range(of: "OVERALL_CONFIDENCE:") {
            let after = response[range.upperBound...].prefix(10)
            if let parsed = Double(after.filter { $0.isNumber || $0 == "." }) {
                confidence = min(1.0, max(0.0, parsed))
            }
        }

        return ExtractionResult(
            entities: entities,
            keyValuePairs: keyValuePairs,
            tables: tables,
            sections: sections,
            metadata: metadata,
            confidence: confidence
        )
    }

    private func parseEntity(_ line: String) -> ExtractionResult.Entity? {
        let content = line.replacingOccurrences(of: "- Type:", with: "")
            .replacingOccurrences(of: "-Type:", with: "")
        let parts = content.components(separatedBy: " | ")

        guard parts.count >= 2 else { return nil }

        var type: ExtractionResult.Entity.EntityType = .custom
        var value = ""
        var context = ""
        var confidence = 0.7

        for part in parts {
            let partTrimmed = part.trimmingCharacters(in: .whitespaces)
            if !partTrimmed.contains(":") {
                // First part is the type
                type = mapEntityType(partTrimmed.lowercased())
            } else if partTrimmed.lowercased().hasPrefix("value:") {
                value = partTrimmed.replacingOccurrences(of: "Value:", with: "")
                    .replacingOccurrences(of: "value:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if partTrimmed.lowercased().hasPrefix("context:") {
                context = partTrimmed.replacingOccurrences(of: "Context:", with: "")
                    .replacingOccurrences(of: "context:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if partTrimmed.lowercased().hasPrefix("confidence:") {
                if let conf = Double(partTrimmed.filter { $0.isNumber || $0 == "." }) {
                    confidence = min(1.0, max(0.0, conf))
                }
            }
        }

        guard !value.isEmpty else { return nil }

        return ExtractionResult.Entity(
            type: type,
            value: value,
            context: context,
            confidence: confidence
        )
    }

    private func mapEntityType(_ typeStr: String) -> ExtractionResult.Entity.EntityType {
        switch typeStr {
        case "person": return .person
        case "organization", "org": return .organization
        case "location", "place": return .location
        case "date", "time": return .date
        case "money", "currency", "amount": return .money
        case "percentage", "percent": return .percentage
        case "product": return .product
        case "email": return .email
        case "phone", "telephone": return .phone
        default: return .custom
        }
    }

    private func parseKeyValuePair(_ line: String) -> ExtractionResult.KeyValuePair? {
        let content = line.replacingOccurrences(of: "- Key:", with: "")
            .replacingOccurrences(of: "-Key:", with: "")
        let parts = content.components(separatedBy: " | ")

        guard parts.count >= 2 else { return nil }

        var key = parts[0].trimmingCharacters(in: .whitespaces)
        var value = ""
        var dataType = "string"
        var confidence = 0.7

        for part in parts.dropFirst() {
            let partTrimmed = part.trimmingCharacters(in: .whitespaces)
            if partTrimmed.lowercased().hasPrefix("value:") {
                value = partTrimmed.replacingOccurrences(of: "Value:", with: "")
                    .replacingOccurrences(of: "value:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if partTrimmed.lowercased().hasPrefix("datatype:") {
                dataType = partTrimmed.replacingOccurrences(of: "DataType:", with: "")
                    .replacingOccurrences(of: "datatype:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if partTrimmed.lowercased().hasPrefix("confidence:") {
                if let conf = Double(partTrimmed.filter { $0.isNumber || $0 == "." }) {
                    confidence = min(1.0, max(0.0, conf))
                }
            }
        }

        guard !key.isEmpty && !value.isEmpty else { return nil }

        return ExtractionResult.KeyValuePair(
            key: key,
            value: value,
            dataType: dataType,
            confidence: confidence
        )
    }

    private func parseTables(_ content: String) -> [ExtractionResult.ExtractedTable] {
        var tables: [ExtractionResult.ExtractedTable] = []
        let lines = content.components(separatedBy: "\n")

        var currentTable: (name: String, headers: [String], rows: [[String]])? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("TABLE:") {
                if let table = currentTable {
                    tables.append(ExtractionResult.ExtractedTable(
                        name: table.name,
                        headers: table.headers,
                        rows: table.rows,
                        rowCount: table.rows.count
                    ))
                }
                let name = trimmed.replacingOccurrences(of: "TABLE:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentTable = (name, [], [])
            } else if trimmed.hasPrefix("Headers:") {
                let headers = trimmed.replacingOccurrences(of: "Headers:", with: "")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                currentTable?.headers = headers
            } else if trimmed.hasPrefix("Row:") {
                let row = trimmed.replacingOccurrences(of: "Row:", with: "")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                currentTable?.rows.append(row)
            } else if trimmed.contains("SECTIONS:") {
                break
            }
        }

        if let table = currentTable {
            tables.append(ExtractionResult.ExtractedTable(
                name: table.name,
                headers: table.headers,
                rows: table.rows,
                rowCount: table.rows.count
            ))
        }

        return tables
    }

    private func parseSectionHeader(_ line: String) -> (level: Int, title: String, wordCount: Int)? {
        let parts = line.components(separatedBy: " | ")
        var level = 1
        var title = ""
        var wordCount = 0

        for part in parts {
            let partTrimmed = part.trimmingCharacters(in: .whitespaces)
            if partTrimmed.contains("Level:") {
                if let lvl = Int(partTrimmed.filter { $0.isNumber }) {
                    level = lvl
                }
            } else if partTrimmed.contains("Title:") {
                title = partTrimmed.replacingOccurrences(of: "Title:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if partTrimmed.contains("WordCount:") {
                if let wc = Int(partTrimmed.filter { $0.isNumber }) {
                    wordCount = wc
                }
            }
        }

        guard !title.isEmpty else { return nil }
        return (level, title, wordCount)
    }

    // MARK: - Helper Methods

    private func generateWithLLM(prompt: String) async throws -> String {
        let response = try await client.generateContent(
            model: .gemini25Pro,
            prompt: prompt,
            generationConfig: GeminiClient.GenerationConfig(temperature: 0.2)
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No response from LLM")
        }

        return text
    }

    private func buildOutput(
        from result: ExtractionResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Document Extraction Report

        ### Document Metadata
        - **Type:** \(result.metadata.documentType)
        - **Language:** \(result.metadata.language)
        - **Word Count:** \(result.metadata.wordCount)
        - **Estimated Pages:** \(result.metadata.pageEstimate)

        """

        if !result.entities.isEmpty {
            content += "\n### Extracted Entities (\(result.entities.count))\n\n"
            for entity in result.entities.prefix(20) {
                content += "- **[\(entity.type.rawValue)]** \(entity.value)"
                if !entity.context.isEmpty {
                    content += " (\(entity.context.prefix(50)))"
                }
                content += "\n"
            }
        }

        if !result.keyValuePairs.isEmpty {
            content += "\n### Key-Value Pairs (\(result.keyValuePairs.count))\n\n"
            for kvp in result.keyValuePairs.prefix(30) {
                content += "| **\(kvp.key)** | \(kvp.value) |\n"
            }
        }

        if !result.tables.isEmpty {
            content += "\n### Tables (\(result.tables.count))\n"
            for table in result.tables {
                content += "\n#### \(table.name)\n"
                content += "| \(table.headers.joined(separator: " | ")) |\n"
                content += "| \(table.headers.map { _ in "---" }.joined(separator: " | ")) |\n"
                for row in table.rows.prefix(10) {
                    content += "| \(row.joined(separator: " | ")) |\n"
                }
            }
        }

        if !result.sections.isEmpty {
            content += "\n### Document Structure (\(result.sections.count) sections)\n\n"
            for section in result.sections {
                let indent = String(repeating: "  ", count: section.level - 1)
                content += "\(indent)- **\(section.title)** (\(section.wordCount) words)\n"
            }
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["entities_count"] = AnySendable(result.entities.count)
        structuredData["kvp_count"] = AnySendable(result.keyValuePairs.count)
        structuredData["tables_count"] = AnySendable(result.tables.count)
        structuredData["sections_count"] = AnySendable(result.sections.count)
        structuredData["document_type"] = AnySendable(result.metadata.documentType)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidence,
            processingTime: processingTime
        )
    }
}
