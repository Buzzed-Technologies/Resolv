import Foundation

enum Config {
    static var openAIApiKey: String {
        // First try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        
        // For development/testing only - should be replaced with proper key in production
        #if DEBUG
        return "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"
        #else
        fatalError("OpenAI API Key not found. Set OPENAI_API_KEY environment variable.")
        #endif
    }
} 
