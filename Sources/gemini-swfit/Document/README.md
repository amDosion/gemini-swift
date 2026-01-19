# Document Module

This module provides document processing capabilities using the Gemini API.

## Architecture

```
Document/
├── GeminiDocumentUploader.swift             # Document file upload handling
├── GeminiDocumentConversationManager.swift  # Multi-turn document conversations
└── README.md                                # This file
```

## Components

### GeminiDocumentUploader

Handles document file uploads:
- Supports PDF, DOCX, TXT, and other document formats
- Metadata extraction
- Session management
- Large file handling

### GeminiDocumentConversationManager

Manages multi-turn conversations about documents:
- Upload and pin documents to conversations
- Query documents with natural language
- Maintain conversation context
- Support multiple documents in one session

## Usage Examples

### Document Upload

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let uploader = GeminiDocumentUploader(
    baseURL: client.baseURL.absoluteString
)

let session = uploader.startSession(apiKey: apiKey)
defer { uploader.endSession(session) }

let fileInfo = try await uploader.uploadDocument(
    at: documentURL,
    displayName: "report.pdf",
    session: session
)
```

### Document Conversation

```swift
let conversationManager = GeminiDocumentConversationManager(
    client: client,
    uploader: uploader
)

// Start a conversation with a document
try await conversationManager.startConversation(
    with: documentURL,
    initialPrompt: "Summarize this document"
)

// Ask follow-up questions
let response = try await conversationManager.sendMessage(
    "What are the key findings in section 3?"
)
```

### Multi-Document Analysis

```swift
// Upload multiple documents
let fileInfos = try await uploader.uploadDocuments(
    at: [doc1URL, doc2URL, doc3URL],
    session: session
)

// Query across all documents
let response = try await client.generateContent(
    model: .gemini25Flash,
    text: "Compare the methodologies used in these three papers",
    fileURIs: fileInfos.map { $0.uri }
)
```

## Supported Formats

| Format | MIME Type | Extensions |
|--------|-----------|------------|
| PDF | application/pdf | .pdf |
| Plain Text | text/plain | .txt |
| HTML | text/html | .html |
| Markdown | text/markdown | .md |
| CSV | text/csv | .csv |
| JSON | application/json | .json |
