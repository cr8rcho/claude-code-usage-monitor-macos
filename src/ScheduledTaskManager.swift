import Foundation
import UserNotifications
import AppKit

struct ScheduledTask: Codable, Identifiable {
    let id: UUID
    var time: Date
    var workingDirectory: String
    var command: String
    var isEnabled: Bool
    var lastExecutionDate: Date?
    var lastExecutionStatus: String?
    
    init(id: UUID = UUID(), time: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(), 
         workingDirectory: String = NSHomeDirectory(), command: String = "hi", isEnabled: Bool = false) {
        self.id = id
        self.time = time
        self.workingDirectory = workingDirectory
        self.command = command
        self.isEnabled = isEnabled
    }
}

enum ExecutionStatus {
    case never
    case success(Date)
    case failed(Date, String)
    case running(Date)
}

class ScheduledTaskManager: ObservableObject {
    @Published var scheduledTasks: [ScheduledTask] = []
    @Published var nextRunDates: [UUID: Date] = [:]
    @Published var executionStatuses: [UUID: ExecutionStatus] = [:]
    
    private var timers: [UUID: Timer] = [:]
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let tasksKey = "scheduledTasks"
    private let legacyEnabledKey = "scheduledTaskEnabled"
    private let legacyTimeKey = "scheduledTaskTime"
    private let legacyWorkingDirectoryKey = "scheduledTaskWorkingDirectory"
    private let legacyCommandKey = "scheduledTaskCommand"
    
    init() {
        loadSettings()
        // Schedule all enabled tasks
        for task in scheduledTasks where task.isEnabled {
            scheduleTask(task)
        }
    }
    
    deinit {
        for timer in timers.values {
            timer.invalidate()
        }
    }
    
    private func loadSettings() {
        // Try to load new format first
        if let tasksData = userDefaults.data(forKey: tasksKey),
           let tasks = try? JSONDecoder().decode([ScheduledTask].self, from: tasksData) {
            scheduledTasks = tasks
            // Load execution statuses
            for task in tasks {
                if let lastExecDate = task.lastExecutionDate,
                   let statusString = task.lastExecutionStatus {
                    switch statusString {
                    case "success":
                        executionStatuses[task.id] = .success(lastExecDate)
                    case let status where status.hasPrefix("failed:"):
                        let errorMessage = String(status.dropFirst(7))
                        executionStatuses[task.id] = .failed(lastExecDate, errorMessage)
                    default:
                        executionStatuses[task.id] = .never
                    }
                } else {
                    executionStatuses[task.id] = .never
                }
            }
        } else {
            // Migrate from old format if exists
            migrateFromLegacySettings()
        }
    }
    
    private func migrateFromLegacySettings() {
        let isEnabled = userDefaults.bool(forKey: legacyEnabledKey)
        
        var scheduledTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        if let savedTimeData = userDefaults.data(forKey: legacyTimeKey),
           let savedTime = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: savedTimeData) as Date? {
            scheduledTime = savedTime
        }
        
        var workingDirectory = NSHomeDirectory()
        if let savedWorkingDir = userDefaults.string(forKey: legacyWorkingDirectoryKey) {
            workingDirectory = savedWorkingDir
        }
        
        var command = "hi"
        if let savedCommand = userDefaults.string(forKey: legacyCommandKey) {
            command = savedCommand
        }
        
        // Create a task from legacy settings
        if isEnabled || command != "hi" {
            let legacyTask = ScheduledTask(
                time: scheduledTime,
                workingDirectory: workingDirectory,
                command: command,
                isEnabled: isEnabled
            )
            scheduledTasks = [legacyTask]
            executionStatuses[legacyTask.id] = .never
            saveSettings()
            
            // Clear legacy settings
            userDefaults.removeObject(forKey: legacyEnabledKey)
            userDefaults.removeObject(forKey: legacyTimeKey)
            userDefaults.removeObject(forKey: legacyWorkingDirectoryKey)
            userDefaults.removeObject(forKey: legacyCommandKey)
        }
    }
    
    func saveSettings() {
        // Update last execution status in tasks
        for i in 0..<scheduledTasks.count {
            let task = scheduledTasks[i]
            if let status = executionStatuses[task.id] {
                switch status {
                case .success(let date):
                    scheduledTasks[i].lastExecutionDate = date
                    scheduledTasks[i].lastExecutionStatus = "success"
                case .failed(let date, let error):
                    scheduledTasks[i].lastExecutionDate = date
                    scheduledTasks[i].lastExecutionStatus = "failed:\(error)"
                default:
                    break
                }
            }
        }
        
        if let tasksData = try? JSONEncoder().encode(scheduledTasks) {
            userDefaults.set(tasksData, forKey: tasksKey)
        }
    }
    
    func addTask() -> ScheduledTask {
        let newTask = ScheduledTask()
        scheduledTasks.append(newTask)
        executionStatuses[newTask.id] = .never
        saveSettings()
        return newTask
    }
    
    func deleteTask(_ task: ScheduledTask) {
        if let index = scheduledTasks.firstIndex(where: { $0.id == task.id }) {
            let removedTask = scheduledTasks.remove(at: index)
            stopTask(removedTask)
            executionStatuses.removeValue(forKey: removedTask.id)
            nextRunDates.removeValue(forKey: removedTask.id)
            saveSettings()
        }
    }
    
    func updateTask(_ task: ScheduledTask) {
        if let index = scheduledTasks.firstIndex(where: { $0.id == task.id }) {
            scheduledTasks[index] = task
            saveSettings()
            
            // Reschedule if needed
            if task.isEnabled {
                scheduleTask(task)
            } else {
                stopTask(task)
            }
        }
    }
    
    func setTaskEnabled(_ task: ScheduledTask, _ enabled: Bool) {
        if let index = scheduledTasks.firstIndex(where: { $0.id == task.id }) {
            scheduledTasks[index].isEnabled = enabled
            saveSettings()
            
            if enabled {
                scheduleTask(scheduledTasks[index])
            } else {
                stopTask(scheduledTasks[index])
            }
        }
    }
    
    private func scheduleTask(_ task: ScheduledTask) {
        // Cancel existing timer if any
        timers[task.id]?.invalidate()
        timers.removeValue(forKey: task.id)
        
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: task.time)
        
        // Calculate next run date
        var nextRun = calendar.nextDate(after: now, matching: timeComponents, matchingPolicy: .nextTime)
        
        // If the time has passed today, schedule for tomorrow
        if let nextRunUnwrapped = nextRun,
           calendar.isDate(nextRunUnwrapped, inSameDayAs: now),
           nextRunUnwrapped <= now {
            nextRun = calendar.nextDate(after: nextRunUnwrapped, matching: timeComponents, matchingPolicy: .nextTime)
        }
        
        guard let targetDate = nextRun else { return }
        
        nextRunDates[task.id] = targetDate
        
        // Schedule timer
        let timer = Timer(fireAt: targetDate, interval: 0, target: self, 
                         selector: #selector(executeClaudeCommand), 
                         userInfo: ["taskId": task.id], repeats: false)
        
        RunLoop.main.add(timer, forMode: .common)
        timers[task.id] = timer
    }
    
    @objc private func executeClaudeCommand(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let taskId = userInfo["taskId"] as? UUID,
              let task = scheduledTasks.first(where: { $0.id == taskId }) else { return }
        
        let executionDate = Date()
        
        DispatchQueue.main.async {
            self.executionStatuses[taskId] = .running(executionDate)
        }
        
        // Force kill Terminal if running, then open fresh and execute claude command
        let script = """
        tell application "System Events"
            if exists (processes where name is "Terminal") then
                do shell script "killall Terminal"
                delay 1
            end if
        end tell
        
        tell application "Terminal"
            activate
            if (count of windows) = 0 then
                do script "cd '\(task.workingDirectory)' && claude '\(task.command)'"
            else
                do script "cd '\(task.workingDirectory)' && claude '\(task.command)'" in window 1
            end if
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        
        DispatchQueue.global(qos: .background).async {
            _ = appleScript?.executeAndReturnError(&errorDict)
            
            DispatchQueue.main.async {
                if let error = errorDict {
                    let errorMessage = "AppleScript error: \(error)"
                    self.executionStatuses[taskId] = .failed(executionDate, errorMessage)
                    self.saveSettings()
                    print("Failed to open Terminal: \(errorMessage)")
                } else {
                    self.executionStatuses[taskId] = .success(executionDate)
                    self.saveSettings()
                    self.showNotification(title: "Claude Auto Launch", body: "Executed '\(task.command)' in Terminal")
                    print("Terminal opened and claude command executed at \(executionDate)")
                }
            }
        }
        
        // Reschedule for tomorrow
        DispatchQueue.main.async {
            if let currentTask = self.scheduledTasks.first(where: { $0.id == taskId }),
               currentTask.isEnabled {
                self.scheduleTask(currentTask)
            }
        }
    }
    
    
    private func stopTask(_ task: ScheduledTask) {
        timers[task.id]?.invalidate()
        timers.removeValue(forKey: task.id)
        nextRunDates.removeValue(forKey: task.id)
    }
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func testClaudeCommand(_ task: ScheduledTask) {
        // Create a timer with task info and execute immediately
        let timer = Timer(fireAt: Date(), interval: 0, target: self,
                         selector: #selector(executeClaudeCommand),
                         userInfo: ["taskId": task.id], repeats: false)
        executeClaudeCommand(timer)
    }
    
    func checkClaudeCommand() {
        let process = Process()
        let homeDir = NSHomeDirectory()
        process.launchPath = "/bin/bash"
        process.arguments = ["-l", "-c", "cd \"\(homeDir)\" && which claude"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                print("✅ Claude found: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                print("❌ Claude not found in PATH from \(homeDir) directory")
                print("Output: \(output)")
            }
        } catch {
            print("❌ Failed to check claude command: \(error)")
        }
    }
    
    func getNextRunString(_ task: ScheduledTask) -> String {
        guard let nextRun = nextRunDates[task.id] else { return "Not scheduled" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let calendar = Calendar.current
        if calendar.isDateInToday(nextRun) {
            return "Today at \(formatter.string(from: nextRun))"
        } else if calendar.isDateInTomorrow(nextRun) {
            return "Tomorrow at \(formatter.string(from: nextRun))"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: nextRun)
        }
    }
    
    func getExecutionStatusString(_ task: ScheduledTask) -> String {
        let status = executionStatuses[task.id] ?? .never
        switch status {
        case .never:
            return "Never executed"
        case .success(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, HH:mm"
            return "✅ Last run: \(formatter.string(from: date))"
        case .failed(let date, let error):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, HH:mm"
            return "❌ Failed: \(formatter.string(from: date)) - \(error)"
        case .running(_):
            return "🔄 Running..."
        }
    }
    
    func getExecutionStatusColor(_ task: ScheduledTask) -> NSColor {
        let status = executionStatuses[task.id] ?? .never
        switch status {
        case .never:
            return .secondaryLabelColor
        case .success:
            return .systemGreen
        case .failed:
            return .systemRed
        case .running:
            return .systemBlue
        }
    }
}