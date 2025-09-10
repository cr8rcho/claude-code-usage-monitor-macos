import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            HeaderView()
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 12)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 10) {
                    if monitor.hasActiveSession {
                        SessionInfoView()
                        
                        TokenUsageView()
                        
                        BurnRateView()
                        
                        PredictionView()
                        
                        AutoLoginView()
                        .padding(.top, 10)
                        
                        ScheduledTaskView()
                    } else {
                        NoSessionView()

                        AutoLoginView()
                        .padding(.top, 10)

                        ScheduledTaskView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .padding(.top, 8)
            }
        }
        .frame(width: 400, height: 535)
    }
}

//MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    @State private var isHoveringPower = false
    @State private var isHoveringPlan = false
    @State private var selectedPlan: String = "Auto"
    
    var displayPlanText: String {
        if monitor.isManualPlanMode {
            return "\(monitor.planType.rawValue) (Manual)"
        } else {
            return monitor.planType.rawValue
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Claude Code Usage Monitor")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power.circle.fill")
                            .foregroundColor(isHoveringPower ? Color(red: 255/255, green: 95/255, blue: 87/255) : Color.primary.opacity(0.6))
                            .imageScale(.large)
                            .animation(.easeInOut(duration: 0.15), value: isHoveringPower)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Claude Usage Monitor")
                    .onHover { hovering in
                        isHoveringPower = hovering
                    }
                }
            
            HStack {
                Menu {
                    Button("Auto") {
                        monitor.setPlanType("Auto")
                    }
                    .disabled(!monitor.isManualPlanMode)
                    
                    Divider()
                    
                    Button("Pro") {
                        monitor.setPlanType("Pro")
                    }
                    .disabled(monitor.isManualPlanMode && monitor.planType == .pro)
                    
                    Button("Max5") {
                        monitor.setPlanType("Max5")
                    }
                    .disabled(monitor.isManualPlanMode && monitor.planType == .max5)
                    
                    Button("Max20") {
                        monitor.setPlanType("Max20")
                    }
                    .disabled(monitor.isManualPlanMode && monitor.planType == .max20)
                } label: {
                    Text("Plan: \(displayPlanText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .fixedSize()
                .menuStyle(.borderlessButton)
                .menuIndicator(isHoveringPlan ? .visible : .hidden)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: isHoveringPlan ? 1 : 0, dash: [3, 2]))
                        .foregroundColor(isHoveringPlan ? .accentColor : Color.clear)
                        .padding(-2)
                )
                .onHover { hovering in
                    isHoveringPlan = hovering
                }
                .help("Select plan mode")
                
                Spacer()
                
                Text("Limit: \(monitor.tokenLimit.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

//MARK: - Session Info Views
struct SessionInfoView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    // DateFormatter cache
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Session")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(monitor.sessionStartTime))
                        .font(.system(.caption, design: .monospaced))
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(sessionDuration())
                        .font(.system(.caption, design: .monospaced))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(monitor.sessionResetTime)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    func formatTime(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
    
    func sessionDuration() -> String {
        let elapsed = Date().timeIntervalSince(monitor.sessionStartTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

//MARK: - Token Usage Views
struct TokenUsageView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token Usage")
                .font(.headline)
            
            ProgressView(value: Double(monitor.currentTokens), total: Double(monitor.tokenLimit))
                .progressViewStyle(ColoredProgressViewStyle(color: Color(monitor.getUsageColor())))
            
            HStack {
                Text("\(monitor.currentTokens.formatted()) / \(monitor.tokenLimit.formatted())")
                    .font(.caption)
                
                Spacer()
                
                Text(String(format: "%.1f%%", monitor.getUsagePercentage()))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            // Model breakdown button
            if monitor.hasActiveSession || monitor.currentTokens > 0 {
                Button(action: {
                    monitor.showModelBreakdown.toggle()
                }) {
                    HStack {
                        Image(systemName: monitor.showModelBreakdown ? "chevron.down" : "chevron.right")
                            .font(.caption)
                        Text("Model Breakdown")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                
                if monitor.showModelBreakdown {
                    ModelBreakdownView()
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

//MARK: - Burn Rate View
struct BurnRateView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Burn Rate (last hour)")
                .font(.headline)
            
            HStack {
                Text(monitor.getBurnRateEmoji())
                    .font(.largeTitle)
                
                VStack(alignment: .leading) {
                    Text("\(Int(monitor.burnRate).formatted()) tokens/min")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(getBurnRateDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(Int(monitor.burnRate * 60).formatted()) tokens/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    func getBurnRateDescription() -> String {
        let rate = monitor.burnRate
        if rate < 100 {
            return "Very slow"
        } else if rate < 300 {
            return "Slow"
        } else if rate < 600 {
            return "Moderate"
        } else if rate < 1000 {
            return "Fast"
        } else if rate < 2000 {
            return "Very fast"
        } else {
            return "Extreme"
        }
    }
}

//MARK: - Prediction View
struct PredictionView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Tokens Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\((monitor.tokenLimit - monitor.currentTokens).formatted())")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Will Last")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(monitor.timeRemaining)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
            }
            
            if monitor.burnRate > 0 {
                let willExceed = monitor.willExceedBeforeReset()
                HStack(spacing: 8) {
                    Image(systemName: willExceed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(willExceed ? .red : .green)
                        .font(.system(size: 14))
                    
                    Text(willExceed ? 
                         "Tokens will run out before session reset!" : 
                         "Tokens will last until session reset")
                        .font(.caption)
                        .foregroundColor(willExceed ? .red : .green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

//MARK: - Colored Progress
struct ColoredProgressViewStyle: ProgressViewStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .cornerRadius(10)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0), height: 16)
                    .cornerRadius(10)
            }
        }
        .frame(height: 20)
    }
}

//MARK: - No Session View
struct NoSessionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Active Session")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start using Claude to see usage statistics")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text("Looking for data in:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("~/.claude/projects/\\*/\\*.jsonl")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("~/.config/claude/projects/\\*/\\*.jsonl")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
}

//MARK: - Auto Login View
struct AutoLoginView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Launch at login")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            updateLaunchAtLoginState()
        }
    }
    
    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status == .enabled {
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    return
                }
                try SMAppService.mainApp.unregister()
            }
            updateLaunchAtLoginState()
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
            updateLaunchAtLoginState()
        }
    }
    
    private func updateLaunchAtLoginState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

//MARK: - Scheduled Task View
struct ScheduledTaskView: View {
    @EnvironmentObject var taskManager: ScheduledTaskManager
    @State private var expandedTasks: Set<UUID> = []
    @State private var editingTasks: [UUID: (workingDirectory: String, command: String)] = [:]
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private func formatTime(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scheduled Claude Code")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    let newTask = taskManager.addTask()
                    expandedTasks.insert(newTask.id)
                    editingTasks[newTask.id] = (workingDirectory: newTask.workingDirectory, command: newTask.command)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("Add new schedule")
            }
            
            if taskManager.scheduledTasks.isEmpty {
                Text("No schedules configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(taskManager.scheduledTasks) { task in
                            ScheduledTaskItemView(
                                task: task,
                                taskManager: taskManager,
                                isExpanded: expandedTasks.contains(task.id),
                                editingValues: Binding(
                                    get: { editingTasks[task.id] ?? (workingDirectory: task.workingDirectory, command: task.command) },
                                    set: { editingTasks[task.id] = $0 }
                                ),
                                onToggleExpand: {
                                    if expandedTasks.contains(task.id) {
                                        expandedTasks.remove(task.id)
                                        editingTasks.removeValue(forKey: task.id)
                                    } else {
                                        expandedTasks.insert(task.id)
                                        editingTasks[task.id] = (workingDirectory: task.workingDirectory, command: task.command)
                                    }
                                },
                                onDelete: {
                                    taskManager.deleteTask(task)
                                    expandedTasks.remove(task.id)
                                    editingTasks.removeValue(forKey: task.id)
                                },
                                onSave: {
                                    if let editing = editingTasks[task.id] {
                                        var updatedTask = task
                                        updatedTask.workingDirectory = editing.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updatedTask.command = editing.command.trimmingCharacters(in: .whitespacesAndNewlines)
                                        taskManager.updateTask(updatedTask)
                                        expandedTasks.remove(task.id)
                                        editingTasks.removeValue(forKey: task.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
                
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            taskManager.requestNotificationPermission()
        }
    }
}

//MARK: - Scheduled Task Item View
struct ScheduledTaskItemView: View {
    let task: ScheduledTask
    let taskManager: ScheduledTaskManager
    let isExpanded: Bool
    @Binding var editingValues: (workingDirectory: String, command: String)
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    
    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    
    enum Field: Hashable {
        case hour
        case minute
        case directory
        case command
    }
    @FocusState private var focusedField: Field?
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private func initializeTimeFields() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: task.time)
        let minute = calendar.component(.minute, from: task.time)
        hourText = String(format: "%02d", hour)
        minuteText = String(format: "%02d", minute)
    }
    
    private func updateTaskTime() {
        guard let hour = Int(hourText), 
              let minute = Int(minuteText),
              hour >= 0, hour < 24,
              minute >= 0, minute < 60 else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: task.time)
        components.hour = hour
        components.minute = minute
        
        if let newTime = calendar.date(from: components) {
            var updatedTask = task
            updatedTask.time = newTime
            taskManager.updateTask(updatedTask)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { task.isEnabled },
                    set: { taskManager.setTaskEnabled(task, $0) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .padding(.leading, -12)
                
                Text(Self.timeFormatter.string(from: task.time))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(task.command)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.9))
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Delete schedule")
            }
            
            // Status row when enabled
            if task.isEnabled {
                HStack {
                    Text("Next: \(taskManager.getNextRunString(task))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(taskManager.getExecutionStatusString(task))
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: taskManager.getExecutionStatusColor(task)))
                }
            }
            
            // Expanded settings
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Time picker
                    HStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        HStack(spacing: 2) {
                            TextField("00", text: $hourText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 35)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .hour)
                                .onSubmit {
                                    focusedField = .minute
                                }
                                .onChange(of: hourText) { newValue in
                                    // Only allow numbers and limit to 2 digits
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 2 {
                                        hourText = String(filtered.prefix(2))
                                    } else if filtered != newValue {
                                        hourText = filtered
                                    }
                                    updateTaskTime()
                                }
                            
                            Text(":")
                                .font(.system(size: 11, design: .monospaced))
                            
                            TextField("00", text: $minuteText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 35)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .minute)
                                .onSubmit {
                                    focusedField = .directory
                                }
                                .onChange(of: minuteText) { newValue in
                                    // Only allow numbers and limit to 2 digits
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 2 {
                                        minuteText = String(filtered.prefix(2))
                                    } else if filtered != newValue {
                                        minuteText = filtered
                                    }
                                    updateTaskTime()
                                }
                        }
                        .onAppear {
                            if hourText.isEmpty && minuteText.isEmpty {
                                initializeTimeFields()
                            }
                        }
                    }
                    
                    // Working Directory
                    HStack {
                        Text("Directory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        TextField("Working Directory", text: $editingValues.workingDirectory)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .focused($focusedField, equals: .directory)
                            .onSubmit {
                                focusedField = .command
                            }
                        
                        Button("📋") {
                            if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                                var cleanedPath = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                if (cleanedPath.hasPrefix("'") && cleanedPath.hasSuffix("'")) ||
                                   (cleanedPath.hasPrefix("\"") && cleanedPath.hasSuffix("\"")) {
                                    cleanedPath = String(cleanedPath.dropFirst().dropLast())
                                }
                                editingValues.workingDirectory = cleanedPath
                            }
                        }
                        .buttonStyle(.borderless)
                        .help("Paste from clipboard")
                    }
                    
                    // Command
                    HStack {
                        Text("Command")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        TextField("Command", text: $editingValues.command)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .focused($focusedField, equals: .command)
                            .onSubmit {
                                // Save when pressing enter on the last field
                                onSave()
                            }
                        
                        Button("📋") {
                            if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                                var cleanedCommand = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                if (cleanedCommand.hasPrefix("'") && cleanedCommand.hasSuffix("'")) ||
                                   (cleanedCommand.hasPrefix("\"") && cleanedCommand.hasSuffix("\"")) {
                                    cleanedCommand = String(cleanedCommand.dropFirst().dropLast())
                                }
                                editingValues.command = cleanedCommand
                            }
                        }
                        .buttonStyle(.borderless)
                        .help("Paste from clipboard")
                    }
                    
                    // Action buttons
                    HStack {
                        Button("Test Now") {
                            taskManager.testClaudeCommand(task)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundColor(.blue)

                        
                        Spacer()
                        
                        Button("Save") {
                            onSave()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

//MARK: - Model Breakdown View
struct ModelBreakdownView: View {
    @EnvironmentObject var monitor: ClaudeUsageMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(monitor.modelBreakdown, id: \.model) { breakdown in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(breakdown.model)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if breakdown.model.lowercased().contains("opus") {
                            Text("(5x)")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Raw Tokens")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(breakdown.rawTokens.formatted())")
                                .font(.system(.caption, design: .monospaced))
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weighted")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(breakdown.weightedTokens.formatted())")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Input/Output")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(breakdown.inputTokens.formatted())/\(breakdown.outputTokens.formatted())")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Only show if cache tokens exist
                    if breakdown.cacheCreationTokens > 0 || breakdown.cacheReadTokens > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("Cache: \(breakdown.cacheCreationTokens.formatted()) created, \(breakdown.cacheReadTokens.formatted()) read")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("(not counted)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
                
                if monitor.modelBreakdown.count > 1 {
                    Divider()
                        .padding(.vertical, 1)
                }
            }
            
            if monitor.modelBreakdown.count > 1 {
                HStack {
                    Text("Total Weighted")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(monitor.currentTokens.formatted()) tokens")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                }
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}
