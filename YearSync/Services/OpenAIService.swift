import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private var apiKey: String
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    enum OpenAIError: Error {
        case invalidResponse
        case networkError
        case decodingError
        case invalidAPIKey
    }
    
    private init() {
        self.apiKey = Config.openAIApiKey
        if apiKey.isEmpty {
            print("Warning: OpenAI API key is not set")
        }
    }
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    func clearAPIKey() {
        self.apiKey = ""
    }
    
    private func sendPrompt(_ prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIError.networkError
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content
    }
    
    func generateDailyTasks(for goals: [Goal], day: Int, previousTasks: [DailyTask], wakeTime: String, sleepTime: String, completion: @escaping (String?) -> Void) {
        var prompt = """
        Create a set of arround 12 daily habit-building tasks and checkpoints for Day \(day) that will help build lasting habits for each goal.
        Distribute the tasks evenly across goals, ensuring each goal has at least 2-3 tasks.

        Goals and Progress:
        """
        
        // Add goals and their progress to prompt
        for goal in goals {
            prompt += "\n- \(goal.title) \(goal.emoji)"
            prompt += "\nStrategy: \(goal.strategy)"
            
            // Add task completion history analysis
            let taskHistory = getTaskProgressAnalysis(for: goal.title, day: day)
            if !taskHistory.isEmpty {
                prompt += "\nProgress: \(taskHistory)"
            }
            
            // Add previous day's incomplete tasks
            let incompleteTasks = previousTasks.filter { $0.goalTitle == goal.title && !$0.isCompleted }
            if !incompleteTasks.isEmpty {
                prompt += "\nIncomplete tasks from previous day:"
                for task in incompleteTasks {
                    prompt += "\n  - \(task.task)"
                }
            }
        }
        
        prompt += """
        \n
        Task Creation Guidelines:
        1. Create arround 12 specific, actionable tasks across all goals (use on emojie for each task no blank tasks)
        2. Focus on building lasting habits
        3. Make each task clear and measurable
        4. Progressive Difficulty: Day \(day) tasks should be \(calculateProgressiveIntensity(day: day))% more challenging
        5. Adapt to completion rate: \(generateCompletionRateGuideline(for: previousTasks))
        6. Include preparation steps when needed
        7. Add specific metrics or targets when relevant
        8. Keep language motivating and supportive
        9. Ensure even distribution across goals

        Example tasks:
        - 🚰 Fill your water bottle to the 32oz mark and keep it visible on your desk
        - 🏃‍♂️ Complete a 20-minute run at a comfortable pace
        - 💰 Review yesterday's expenses and categorize them
        - 🧘‍♀️ Practice deep breathing for 5 minutes
        - 📱 Use app limits to reduce screen time
        - 🥗 Prepare a healthy lunch with protein and vegetables

        Format response as JSON with structure:
        {
          "dailyTasks": [
            {
              "goalTitle": "exact goal title",
              "tasks": [
                {
                  "description": "specific habit-building task",
                  "emoji": "relevant emoji"
                }
              ]
            }
          ]
        }
        """
        
        print("Sending daily tasks prompt to OpenAI:", prompt)
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": """
                You are a habit formation coach that creates practical daily tasks.
                You must ALWAYS respond with ONLY valid JSON that matches exactly this structure:
                {
                  "dailyTasks": [
                    {
                      "goalTitle": "exact goal title from user",
                      "tasks": [
                        {
                          "description": "habit-building task",
                          "emoji": "relevant emoji"
                        }
                      ]
                    }
                  ]
                }
                Rules for tasks:
                1. Focus on building lasting habits
                2. Make each task specific and actionable
                3. Include clear success criteria
                4. Use relevant emojis for each task type:
                   - Exercise/Movement: 🏃‍♂️🚶‍♂️🏋️‍♂️🧘‍♂️
                   - Food/Drink: 🥤🍎🥗
                   - Sleep/Rest: 😴🛏️
                   - Reading/Learning: 📚📖
                   - Meditation/Mindfulness: 🧘‍♂️🙏
                   - Cleaning/Organization: 🧹🧼
                   - Work/Focus: 💼💻
                   - Social/Communication: 👥💬
                Remember: Respond with ONLY the JSON, no other text.
                """],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 2000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error creating request body:", error)
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error:", error)
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpResponse.statusCode)
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw API Response:", rawResponse)
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("Parsed content:", content)
                    completion(content)
                } else {
                    print("Failed to parse response structure")
                    completion(nil)
                }
            } catch {
                print("JSON parsing error:", error)
                completion(nil)
            }
        }.resume()
    }
    
    func generatePlan(for goals: [String], duration: Int, completion: @escaping (String?) -> Void) {
        var prompt = """
        Create a transformative \(duration)-day plan for these habit-building goals:

        Goals:
        \(goals.map { "- \($0)" }.joined(separator: "\n"))

        For each goal, provide:
        1. A motivating paragraph explaining how to transform this area of life in \(duration) days
        2. 3-4 specific daily/weekly habits that will lead to being 100x better at this goal
        3. Focus on sustainable, long-term behavior change
        4. Consider the psychology of habit formation
        5. Explain how these changes compound over the \(duration)-day period

        Example response for "Drink more water":
        {
          "title": "Drink more water",
          "strategy": "Over the next \(duration) days, we'll rewire your hydration habits by creating multiple daily triggers for water consumption. By linking water intake to existing habits and making it incredibly convenient, you'll naturally increase your daily water intake. The key is to start with small, manageable amounts and gradually increase, while building strong environmental cues that make drinking water your default behavior.",
          "subPlans": [
            "Place a full water bottle next to your bed each night - it's your first action each morning",
            "Drink one full glass of water before each meal - use meals as triggers",
            "Set up water stations at your desk, car, and bag - make it impossible to forget"
          ]
        }

        Format the response as JSON with this exact structure:
        {
          "goals": [
            {
              "title": "exact goal title",
              "strategy": "Transformative strategy paragraph",
              "subPlans": [
                "Specific habit 1",
                "Specific habit 2",
                "Specific habit 3"
              ]
            }
          ]
        }
        """
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": """
                You are a transformative habit coach who helps people achieve dramatic improvements through small, consistent changes.
                For each goal:
                1. Write an inspiring yet practical strategy paragraph
                2. Focus on the compound effect of small daily actions
                3. Create habits that attach to existing behaviors
                4. Make the path to improvement crystal clear
                5. Keep everything simple and achievable
                
                The strategy should feel like a personal coach explaining exactly how to transform this area of life.
                Focus on the psychology of habit formation and making changes stick.
                Remember: Respond with ONLY valid JSON that matches exactly the specified structure.
                """],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error creating request body:", error)
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error:", error)
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpResponse.statusCode)
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw API Response:", rawResponse)
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("Parsed content:", content)
                    completion(content)
                } else {
                    print("Failed to parse response structure")
                    completion(nil)
                }
            } catch {
                print("JSON parsing error:", error)
                completion(nil)
            }
        }.resume()
    }
    
    func generateDailySummary(day: Int, totalDays: Int, name: String?, goals: [Goal], previousDayCompletion: Double?, completion: @escaping (String?) -> Void) {
        var prompt = "Create a short, motivational message for \(name ?? "the user")'s habit-building journey.\n\n"
        prompt += "Context:\n"
        prompt += "- Day \(day) of \(totalDays)\n"
        prompt += "- Goals: \(goals.map { $0.title }.joined(separator: ", "))\n"
        
        if let previousCompletion = previousDayCompletion {
            prompt += "- Previous day completion rate: \(Int(previousCompletion * 100))%\n"
        }
        
        prompt += "\nThe message should:\n"
        prompt += "1. Be short and direct (max 1-2 sentences)\n"
        prompt += "2. Focus on progress and momentum\n"
        prompt += "3. Vary based on the stage of the journey (beginning/middle/end)\n"
        prompt += "4. Acknowledge effort and encourage consistency\n"
        prompt += "5. Be natural and conversational\n"
        prompt += "6. Never use quotes or emojis\n\n"
        prompt += "Examples of good messages:\n"
        prompt += "- Starting strong today with small steps toward big changes.\n"
        prompt += "- Each completed task is building your foundation for success.\n"
        prompt += "- Halfway there and getting stronger every day.\n"
        prompt += "- Making progress one task at a time, stay focused.\n"
        prompt += "- Almost at the finish line, keep up that momentum.\n"
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": """
                You are a supportive coach who focuses on progress and consistency.
                Write in a natural, conversational tone.
                Keep messages short and impactful.
                Never use quotes, emojis, or pop culture references.
                Focus on building habits and maintaining momentum.
                Adapt your tone based on the user's progress and current day.
                """],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 100
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error creating request body:", error)
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error:", error)
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    print("Failed to parse response structure")
                    completion(nil)
                }
            } catch {
                print("JSON parsing error:", error)
                completion(nil)
            }
        }.resume()
    }
    
    func analyzeWeeklyJournalEntries(_ entries: [JournalEntry]) async throws -> (analysis: String, suggestedGoals: [String]) {
        let entriesText = entries.map { """
            Date: \(formatDate($0.date))
            Journal Entry: \($0.content)
            Completed Tasks: \($0.completedTasks.joined(separator: ", "))
            """ }.joined(separator: "\n\n")
        
        let prompt = """
        Analyze the following week of journal entries and completed tasks:
        
        \(entriesText)
        
        Please provide:
        1. A concise summary of the week's key themes, patterns, and emotional state
        2. Three specific goal suggestions based on the journal content and completed tasks
        
        Format the response as JSON with the following structure:
        {
            "analysis": "your analysis here",
            "suggestedGoals": ["goal 1", "goal 2", "goal 3"]
        }
        """
        
        let response = try await sendPrompt(prompt)
        
        guard let data = response.data(using: .utf8),
              let result = try? JSONDecoder().decode(WeeklyAnalysis.self, from: data) else {
            throw OpenAIError.invalidResponse
        }
        
        return (result.analysis, result.suggestedGoals)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func generateUserProfileSection() -> String {
        var profile = ""
        if let userData = UserDefaults.standard.data(forKey: "userData"),
           let user = try? JSONDecoder().decode(UserData.self, from: userData) {
            if let age = user.age { profile += "\nAge: \(age)" }
            if let height = user.height { profile += "\nHeight: \(height) cm" }
            if let weight = user.weight { profile += "\nWeight: \(weight) kg" }
            if let sex = user.sex { profile += "\nSex: \(sex)" }
        }
        return profile.isEmpty ? "No specific user data available" : profile
    }
    
    private func calculateProgressiveIntensity(day: Int) -> Int {
        // Calculate progressive intensity based on day number
        // Start at 100% and increase by 5% every 3 days
        let baseIntensity = 100
        let intensityIncrease = (day - 1) / 3 * 5
        return baseIntensity + intensityIncrease
    }
    
    private func getTaskProgressAnalysis(for goalTitle: String, day: Int) -> String {
        // Safely unwrap the optional userData
        guard let userDataRaw = UserDefaults.standard.data(forKey: "userData"),
              let userData = try? JSONDecoder().decode(UserData.self, from: userDataRaw),
              !userData.dailyTaskHistory.isEmpty else {
            return ""
        }
        
        let relevantTasks = userData.getTaskHistory(for: goalTitle)
        let completedTasks = relevantTasks.filter { $0.isCompleted }
        
        // Guard against division by zero
        guard !relevantTasks.isEmpty else { return "" }
        let completionRate = Double(completedTasks.count) / Double(relevantTasks.count)
        
        return "Completion rate: \(Int(completionRate * 100))%"
    }
    
    private func generateCompletionRateGuideline(for previousTasks: [DailyTask]) -> String {
        guard !previousTasks.isEmpty else {
            return "Start with beginner-friendly tasks"
        }
        
        let completionRate = Double(previousTasks.filter { $0.isCompleted }.count) / Double(previousTasks.count)
        
        if completionRate >= 0.8 {
            return "User is handling tasks well - increase difficulty"
        } else if completionRate >= 0.5 {
            return "Maintain current difficulty but optimize timing"
        } else {
            return "Simplify tasks and focus on building consistency"
        }
    }
    
    func processJournalMessage(_ messages: [Message]) async throws -> String {
        let conversationHistory = messages.map { message in
            [
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ]
        }
        
        let systemPrompt = """
        You are an insightful and empathetic journaling companion, helping users explore and understand their daily experiences more deeply. Your role is to create a natural flow of reflection that reads like a thoughtful conversation between friends.

        Guidelines for responses:
        1. Help users unpack their experiences by gently exploring specific moments or feelings they mention
        2. Notice patterns and connections in their day, pointing out insights they might have missed
        3. For challenges or difficulties:
           - Acknowledge the emotion
           - Help identify what could be learned
           - Suggest specific, actionable steps for tomorrow
           - Keep the tone encouraging and growth-focused
        
        4. For positive experiences:
           - Help them savor the moment by exploring what made it special
           - Identify what strategies or choices led to the success
           - Suggest how to recreate similar positive experiences
        
        5. Writing style:
           - Write like a thoughtful friend having a natural conversation
           - Use phrases like "I notice that..." or "It sounds like..."
           - Keep responses focused but warm
           - Avoid generic advice - make suggestions specific to their situation
        
        6. End each response with either:
           - A gentle question that explores deeper
           - A specific observation about their growth
           - A concrete suggestion for tomorrow
        
        Remember: The goal is to help them process their day in a way that feels like writing in a journal with a wise friend who helps them understand themselves better.
        """
        
        var allMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        allMessages.append(contentsOf: conversationHistory)
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": allMessages,
            "temperature": 0.7,
            "max_tokens": 150  // Keep responses concise
        ]
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIError.networkError
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content
    }
}

// Response models for OpenAI
struct PlanResponse: Codable {
    struct GeneratedGoal: Codable {
        let title: String
        let strategy: String
        let subPlans: [String]
    }
    
    let goals: [GeneratedGoal]
}

struct WeeklyAnalysis: Codable {
    let analysis: String
    let suggestedGoals: [String]
} 