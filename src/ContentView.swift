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
    @StateObject private var taskManager = ScheduledTaskManager()
    @State private var showSettings = false
    @State private var tempWorkingDirectory = ""
    @State private var tempCommand = ""
    
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
                
                Toggle("", isOn: Binding(
                    get: { taskManager.isEnabled },
                    set: { taskManager.setEnabled($0) }
                ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
            }
            
            if taskManager.isEnabled {
                HStack {
                    Text("Next run: \(taskManager.getNextRunString())")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Execution status
                HStack {
                    Text(taskManager.getExecutionStatusString())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(nsColor: taskManager.getExecutionStatusColor()))
                    
                    Spacer()
                    
                    Button("Test Now") {
                        taskManager.testClaudeCommand()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(.top, 2)
                
                // Settings toggle
                Button(action: {
                    if !showSettings {
                        tempWorkingDirectory = taskManager.workingDirectory
                        tempCommand = taskManager.command
                    }
                    showSettings.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                                // Settings section
                if showSettings {
                    VStack(alignment: .leading, spacing: 8) {
                        // Schedule Time
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Schedule Time:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: Binding(
                                get: { taskManager.scheduledTime },
                                set: { taskManager.setTime($0) }
                            ), displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.stepperField)
                                .labelsHidden()
                        }
                        
                        // Working Directory
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Working Directory:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Working Directory", text: $tempWorkingDirectory)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.caption, design: .monospaced))
                                    .onTapGesture {
                                        // Force focus for better keyboard support
                                    }
                                
                                Button("📋") {
                                    if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                                        var cleanedPath = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                        // Remove surrounding quotes if present
                                        if (cleanedPath.hasPrefix("'") && cleanedPath.hasSuffix("'")) ||
                                           (cleanedPath.hasPrefix("\"") && cleanedPath.hasSuffix("\"")) {
                                            cleanedPath = String(cleanedPath.dropFirst().dropLast())
                                        }
                                        tempWorkingDirectory = cleanedPath
                                    }
                                }
                                .buttonStyle(.borderless)
                                .help("Paste from clipboard")
                            }
                        }
                        
                        // Command
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Claude Command:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Command", text: $tempCommand)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.caption, design: .monospaced))
                                    .onTapGesture {
                                        // Force focus for better keyboard support
                                    }
                                
                                Button("📋") {
                                    if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                                        var cleanedCommand = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                        // Remove surrounding quotes if present
                                        if (cleanedCommand.hasPrefix("'") && cleanedCommand.hasSuffix("'")) ||
                                           (cleanedCommand.hasPrefix("\"") && cleanedCommand.hasSuffix("\"")) {
                                            cleanedCommand = String(cleanedCommand.dropFirst().dropLast())
                                        }
                                        tempCommand = cleanedCommand
                                    }
                                }
                                .buttonStyle(.borderless)
                                .help("Paste from clipboard")
                            }
                        }
                        
                        // Save button
                        HStack {
                            Spacer()
                            
                            Button("Save Settings") {
                                // Clean the working directory path before saving
                                var cleanedDir = tempWorkingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                                if (cleanedDir.hasPrefix("'") && cleanedDir.hasSuffix("'")) ||
                                   (cleanedDir.hasPrefix("\"") && cleanedDir.hasSuffix("\"")) {
                                    cleanedDir = String(cleanedDir.dropFirst().dropLast())
                                }
                                
                                // Clean the command before saving
                                var cleanedCmd = tempCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                                if (cleanedCmd.hasPrefix("'") && cleanedCmd.hasSuffix("'")) ||
                                   (cleanedCmd.hasPrefix("\"") && cleanedCmd.hasSuffix("\"")) {
                                    cleanedCmd = String(cleanedCmd.dropFirst().dropLast())
                                }
                                
                                taskManager.saveWorkingDirectory(cleanedDir)
                                taskManager.saveCommand(cleanedCmd)
                                showSettings = false
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
                    .cornerRadius(6)
                }
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