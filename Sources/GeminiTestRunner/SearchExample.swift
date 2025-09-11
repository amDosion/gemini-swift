import Foundation
import gemini_swfit

public class SearchExample {
    
    public static func runGoogleSearchExample() async {
        print("=== Google Search Example ===")
        
        // Initialize the client with your API key
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            print("\n1. Google Search Example:")
            print("Question: Who won the euro 2024?")
            
            let response = try await client.generateContentWithGoogleSearch(
                model: .gemini25Flash,
                text: "Who won the euro 2024?"
            )
            
            if let candidate = response.candidates.first,
               let text = candidate.content.parts.first?.text {
                print("\nAnswer: \(text)")
                
                // Print grounding metadata if available
                if let groundingMetadata = candidate.groundingMetadata {
                    print("\n--- Grounding Information ---")
                    if let queries = groundingMetadata.webSearchQueries {
                        print("Search queries: \(queries.joined(separator: ", "))")
                    }
                    if let chunks = groundingMetadata.groundingChunks {
                        print("Sources:")
                        for (index, chunk) in chunks.enumerated() {
                            if let web = chunk.web {
                                print("  \(index + 1). \(web.title ?? "Untitled") - \(web.uri ?? "No URL")")
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    public static func runUrlContextExample() async {
        print("\n=== URL Context Example ===")
        
        // Initialize the client with your API key
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            print("\n2. URL Context Example:")
            let query = """
            Compare the ingredients and cooking times from the recipes at 
            https://www.foodnetwork.com/recipes/ina-garten/perfect-roast-chicken-recipe-1940592 and 
            https://www.allrecipes.com/recipe/21151/simple-whole-roast-chicken/
            """
            
            print("Query: \(query)")
            
            // Ask for user confirmation before accessing URLs
            let response = try await client.generateContentWithUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\nDetected URLs:")
                    for url in urls {
                        print("  - \(url.absoluteString)")
                    }
                    print("\nDo you want to allow Gemini to access these URLs? (y/n)")
                    
                    if let input = readLine(), input.lowercased() == "y" {
                        return true
                    }
                    return false
                }
            )
            
            if let candidate = response.candidates.first,
               let text = candidate.content.parts.first?.text {
                print("\nAnswer: \(text)")
                
                // Print grounding metadata if available
                if let groundingMetadata = candidate.groundingMetadata {
                    print("\n--- Grounding Information ---")
                    if let chunks = groundingMetadata.groundingChunks {
                        print("Sources:")
                        for (index, chunk) in chunks.enumerated() {
                            if let web = chunk.web {
                                print("  \(index + 1). \(web.title ?? "Untitled") - \(web.uri ?? "No URL")")
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    public static func runCombinedToolsExample() async {
        print("\n=== Combined Tools Example ===")
        
        // Initialize the client with your API key
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            print("\n3. Combined Search and URL Context Example:")
            let query = "Give me three day events schedule based on https://www.eventbrite.com/. Also let me know what needs to taken care of considering weather and commute."
            
            print("Query: \(query)")
            
            // Ask for user confirmation before accessing URLs
            let response = try await client.generateContentWithSearchAndUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\nDetected URLs:")
                    for url in urls {
                        print("  - \(url.absoluteString)")
                    }
                    print("\nDo you want to allow Gemini to access these URLs and search the web? (y/n)")
                    
                    if let input = readLine(), input.lowercased() == "y" {
                        return true
                    }
                    return false
                }
            )
            
            if let candidate = response.candidates.first,
               let text = candidate.content.parts.first?.text {
                print("\nAnswer: \(text)")
                
                // Print grounding metadata if available
                if let groundingMetadata = candidate.groundingMetadata {
                    print("\n--- Grounding Information ---")
                    if let queries = groundingMetadata.webSearchQueries {
                        print("Search queries: \(queries.joined(separator: ", "))")
                    }
                    if let chunks = groundingMetadata.groundingChunks {
                        print("Sources:")
                        for (index, chunk) in chunks.enumerated() {
                            if let web = chunk.web {
                                print("  \(index + 1). \(web.title ?? "Untitled") - \(web.uri ?? "No URL")")
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    public static func runAllExamples() async {
        await runGoogleSearchExample()
        await runUrlContextExample()
        await runCombinedToolsExample()
    }
}