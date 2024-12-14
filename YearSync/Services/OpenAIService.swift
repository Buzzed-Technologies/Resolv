import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey = "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"
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    enum OpenAIError: Error {
        case invalidResponse
        case networkError
        case decodingError
    }
    
    private init() {}
    
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
        Create a progressive, personalized daily schedule for Day \(day) considering:

        User Profile:
        \(generateUserProfileSection())

        Goals and Progress:
        """
        
        // Add goals and their progress to prompt
        for goal in goals {
            prompt += "\n- \(goal.title) \(goal.emoji)"
            
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
                    prompt += "\n  - \(task.task) (was scheduled for \(task.formattedTime))"
                }
            }
        }
        
        prompt += """
        \n
        Task Creation Guidelines:
        1. Create highly specific, actionable tasks that fit into the user's daily routine
        2. Tasks should be time-appropriate (e.g., meal prep in morning/evening, exercise when energy is high)
        3. Consider real-world context and practicality:
           - For saving money: Suggest specific money-saving actions at relevant times (e.g., "Pack lunch for tomorrow at 8:00 PM")
           - For exercise: Include warm-up and proper form reminders
           - For meditation: Suggest quiet times of day
           - For reading: Recommend specific durations and ideal times
           - For water/nutrition: Time reminders around meals and activities
        4. Progressive Difficulty: Day \(day) tasks should be \(calculateProgressiveIntensity(day: day))% more challenging than initial days
        5. Adapt to completion rate: \(generateCompletionRateGuideline(for: previousTasks))
        6. Space tasks throughout active hours (\(wakeTime) to \(sleepTime))
        7. Include preparation tasks when relevant (e.g., "Prepare gym bag for tomorrow's workout")
        8. Add specific metrics when possible (e.g., "Walk 2000 steps" instead of just "Take a walk")
        9. Consider task dependencies and natural flow of the day
        10. Tasks should build upon previous successes

        Example tasks for different goals:
        - Save money: "I suggest preparing a homemade lunch: turkey sandwich and fruit"
        - Exercise: "I suggest starting with a 10-minute warm-up, then doing a 20-minute HIIT workout: 45s work, 15s rest"
        - Meditation: "I suggest finding a quiet room for your evening meditation: 5 minutes breathing focus, 5 minutes body scan"
        - Water intake: "I suggest filling your water bottle and placing it by your desk before starting work"
        - Reading: "I suggest reading 20 pages of your current book before bed, in a quiet room with good lighting"

        Task Writing Style:
        1. Start specific recommendations with "I suggest" to make them more personal and suggestive
        2. Use a friendly, coaching tone
        3. Explain the benefits or reasoning when relevant
        4. For exact instructions or metrics, always start with "I suggest"
        5. Keep the tone encouraging and supportive

        Examples of good task phrasing:
        - "I suggest going for a 30-minute run at a comfortable pace to build your endurance"
        - "I suggest preparing overnight oats now for a healthy breakfast tomorrow (saves time and money)"
        - "I suggest practicing meditation for 10 minutes in a quiet space to reduce stress"
        - "I suggest reviewing your expenses from today and updating your budget tracker"

        Format response as JSON with structure:
        {
          "dailyTasks": [
            {
              "goalTitle": "exact goal title",
              "tasks": [
                {
                  "description": "specific progressive task starting with 'I suggest' when giving exact recommendations",
                  "time": "HH:MM AM/PM",
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
                You are a motivating personal coach that creates fun and engaging daily schedules.
                You must ALWAYS respond with ONLY valid JSON that matches exactly this structure:
                {
                  "dailyTasks": [
                    {
                      "goalTitle": "exact goal title from user",
                      "tasks": [
                        {
                          "description": "task description",
                          "time": "9:00 AM",
                          "emoji": "relevant emoji"
                        }
                      ]
                    }
                  ]
                }
                Rules for task scheduling:
                1. Only schedule tasks during user's active hours
                2. Space tasks appropriately throughout the day
                3. Consider task dependencies and natural flow
                4. Use specific times (HH:MM AM/PM format)
                5. Choose relevant emojis for each task type:
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
        Create a detailed \(duration)-day plan for each of these goals:

        Goals:
        \(goals.map { "- \($0)" }.joined(separator: "\n"))

        For each goal:
        1. Break down the goal into 3-4 specific, actionable sub-tasks
        2. Make each sub-task clear and measurable
        3. Focus on building sustainable habits
        4. Consider the \(duration)-day timeframe
        5. Make tasks engaging and achievable

        Requirements for sub-tasks:
        - Start with action verbs
        - Be specific and measurable
        - Focus on daily or weekly actions
        - Include target numbers or durations when relevant
        - Keep language simple and direct

        Example format for "Drink more water":
        - Drink 8 cups of water every day
        - Keep a water bottle within arm's reach at all times
        - Track water intake in the morning and evening
        - Set reminders for every 2 hours during the day

        Example format for "Lift":
        - Work out twice a week, focusing on proper form
        - Start with bodyweight exercises to build foundation
        - Follow a progressive overload plan
        - Schedule rest days between workouts

        Format the response as JSON with this exact structure:
        {
          "goals": [
            {
              "title": "exact goal title",
              "strategy": "Brief explanation of the approach",
              "subPlans": [
                "Specific task 1",
                "Specific task 2",
                "Specific task 3"
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
                You are an expert coach who creates detailed, actionable plans.
                For each goal:
                1. Create a clear progression strategy
                2. Explain how the approach will evolve over time
                3. Be specific about methods and activities
                4. Include measurable milestones
                5. Consider the user's starting point
                6. Make it engaging and achievable
                
                The strategy should read like a coach explaining their approach.
                Focus on practical, actionable steps and clear progression.
                Avoid generic advice - be specific about methods and activities.
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
        
        var analysis = "Completion rate: \(Int(completionRate * 100))%"
        
        // Analyze timing patterns
        guard !completedTasks.isEmpty else { return analysis }
        let onTimeTasks = completedTasks.filter { $0.completionStatus == .onTime }
        let onTimeRate = Double(onTimeTasks.count) / Double(completedTasks.count)
        analysis += "\nOn-time completion: \(Int(onTimeRate * 100))%"
        
        return analysis
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
}

private struct WeeklyAnalysis: Codable {
    let analysis: String
    let suggestedGoals: [String]
} 