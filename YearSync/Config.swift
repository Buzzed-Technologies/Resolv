import Foundation

enum Config {
    static var openAIApiKey: String {
        // First try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        
        // For development/testing only - should be replaced with proper key in production
        #if DEBUG
        return "sk-svcacct-FZCgvTqICurM5TXuA0EEuBdeIxSyDsEIxHvceVvLYhGr3l_DtMGP2Qiq4p6wL0bT3BlbkFJWwBsuP4ZcxeGADBoYLD327bxfllFIP2pZ_DRvyF4oFRA7DAwoFhDMpZ3s-yPfsQA"
        #else
        fatalError("OpenAI API Key not found. Set OPENAI_API_KEY environment variable.")
        #endif
    }
} 
