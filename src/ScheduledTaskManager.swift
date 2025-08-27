import Foundation
import UserNotifications
import AppKit

enum ExecutionStatus {
    case never
    case success(Date)
    case failed(Date, String)
    case running(Date)
}

class ScheduledTaskManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var scheduledTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var nextRunDate: Date?
    @Published var lastExecutionStatus: ExecutionStatus = .never
    @Published var workingDirectory: String = NSHomeDirectory()
    @Published var command: String = "hi"
    
    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let enabledKey = "scheduledTaskEnabled"
    private let timeKey = "scheduledTaskTime"
    private let lastExecutionKey = "lastExecutionDate"
    private let lastExecutionStatusKey = "lastExecutionStatus"
    private let workingDirectoryKey = "scheduledTaskWorkingDirectory"
    private let commandKey = "scheduledTaskCommand"
    
    init() {
        loadSettings()
        if isEnabled {
            scheduleTask()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: enabledKey)
        
        if let savedTimeData = userDefaults.data(forKey: timeKey),
           let savedTime = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: savedTimeData) as Date? {
            scheduledTime = savedTime
        }
        
        // Load working directory and command
        if let savedWorkingDir = userDefaults.string(forKey: workingDirectoryKey) {
            workingDirectory = savedWorkingDir
        }
        
        if let savedCommand = userDefaults.string(forKey: commandKey) {
            command = savedCommand
        }
        
        // Load last execution status
        if let lastExecDate = userDefaults.object(forKey: lastExecutionKey) as? Date,
           let statusString = userDefaults.string(forKey: lastExecutionStatusKey) {
            switch statusString {
            case "success":
                lastExecutionStatus = .success(lastExecDate)
            case let status where status.hasPrefix("failed:"):
                let errorMessage = String(status.dropFirst(7))
                lastExecutionStatus = .failed(lastExecDate, errorMessage)
            default:
                lastExecutionStatus = .never
            }
        }
    }
    
    func saveSettings() {
        userDefaults.set(isEnabled, forKey: enabledKey)
        userDefaults.set(workingDirectory, forKey: workingDirectoryKey)
        userDefaults.set(command, forKey: commandKey)
        
        if let timeData = try? NSKeyedArchiver.archivedData(withRootObject: scheduledTime, requiringSecureCoding: false) {
            userDefaults.set(timeData, forKey: timeKey)
        }
    }
    
    func saveWorkingDirectory(_ directory: String) {
        workingDirectory = directory
        saveSettings()
    }
    
    func saveCommand(_ cmd: String) {
        command = cmd
        saveSettings()
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
        
        if enabled {
            scheduleTask()
        } else {
            stopTask()
        }
    }
    
    func setTime(_ time: Date) {
        scheduledTime = time
        saveSettings()
        
        if isEnabled {
            scheduleTask()
        }
    }
    
    private func scheduleTask() {
        timer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        
        // Calculate next run date
        var nextRun = calendar.nextDate(after: now, matching: timeComponents, matchingPolicy: .nextTime)
        
        // If the time has passed today, schedule for tomorrow
        if let nextRunUnwrapped = nextRun,
           calendar.isDate(nextRunUnwrapped, inSameDayAs: now),
           nextRunUnwrapped <= now {
            nextRun = calendar.nextDate(after: nextRunUnwrapped, matching: timeComponents, matchingPolicy: .nextTime)
        }
        
        guard let targetDate = nextRun else { return }
        
        nextRunDate = targetDate
        
        // Schedule timer
        timer = Timer(fireAt: targetDate, interval: 0, target: self, selector: #selector(executeClaudeCommand), userInfo: nil, repeats: false)
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Schedule the next day's task
        let nextDayDate = calendar.date(byAdding: .day, value: 1, to: targetDate)
        if let nextDay = nextDayDate {
            let nextDayTimer = Timer(fireAt: nextDay, interval: 0, target: self, selector: #selector(rescheduleForNextDay), userInfo: nil, repeats: false)
            RunLoop.main.add(nextDayTimer, forMode: .common)
        }
    }
    
    @objc private func executeClaudeCommand() {
        let executionDate = Date()
        
        DispatchQueue.main.async {
            self.lastExecutionStatus = .running(executionDate)
        }
        
        // Open Terminal and execute claude command
        let script = """
        tell application "Terminal"
            activate
            if (count of windows) = 0 then
                do script "cd '\(workingDirectory)' && claude '\(command)'"
            else
                do script "cd '\(workingDirectory)' && claude '\(command)'" in window 1
            end if
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        
        DispatchQueue.global(qos: .background).async {
            let result = appleScript?.executeAndReturnError(&errorDict)
            
            DispatchQueue.main.async {
                if let error = errorDict {
                    let errorMessage = "AppleScript error: \(error)"
                    self.lastExecutionStatus = .failed(executionDate, errorMessage)
                    self.saveExecutionStatus(.failed(executionDate, errorMessage))
                    print("Failed to open Terminal: \(errorMessage)")
                } else {
                    self.lastExecutionStatus = .success(executionDate)
                    self.saveExecutionStatus(.success(executionDate))
                    self.showNotification(title: "Claude Auto Launch", body: "Opened Terminal and executed 'claude \(self.command)' command")
                    print("Terminal opened and claude command executed at \(executionDate)")
                }
            }
        }
        
        // Reschedule for tomorrow
        DispatchQueue.main.async {
            self.scheduleTask()
        }
    }
    
    @objc private func rescheduleForNextDay() {
        if isEnabled {
            DispatchQueue.main.async {
                self.scheduleTask()
            }
        }
    }
    
    private func stopTask() {
        timer?.invalidate()
        timer = nil
        nextRunDate = nil
    }
    
    private func saveExecutionStatus(_ status: ExecutionStatus) {
        switch status {
        case .success(let date):
            userDefaults.set(date, forKey: lastExecutionKey)
            userDefaults.set("success", forKey: lastExecutionStatusKey)
        case .failed(let date, let error):
            userDefaults.set(date, forKey: lastExecutionKey)
            userDefaults.set("failed:\(error)", forKey: lastExecutionStatusKey)
        default:
            break
        }
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
    
    func testClaudeCommand() {
        executeClaudeCommand()
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
    
    func getNextRunString() -> String {
        guard let nextRun = nextRunDate else { return "Not scheduled" }
        
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
    
    func getExecutionStatusString() -> String {
        switch lastExecutionStatus {
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
        case .running(let date):
            return "🔄 Running..."
        }
    }
    
    func getExecutionStatusColor() -> NSColor {
        switch lastExecutionStatus {
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