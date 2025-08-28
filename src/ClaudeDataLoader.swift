import Foundation

actor ClaudeDataLoader {
    private let fileManager = FileManager.default
    private var processedHashes: Set<String> = []
    
    private var claudePaths: [URL] {
        var paths: [URL] = []
        
        if let claudeDataPaths = ProcessInfo.processInfo.environment["CLAUDE_DATA_PATHS"] {
            let pathStrings = claudeDataPaths.split(separator: ":").map(String.init)
            paths.append(contentsOf: pathStrings.compactMap { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) })
        } else if let claudeDataPath = ProcessInfo.processInfo.environment["CLAUDE_DATA_PATH"] {
            paths.append(URL(fileURLWithPath: (claudeDataPath as NSString).expandingTildeInPath))
        } else {
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            let defaultPaths = [
                homeDirectory.appendingPathComponent(".claude/projects"),
                homeDirectory.appendingPathComponent(".config/claude/projects")
            ]
            
            for path in defaultPaths {
                if fileManager.fileExists(atPath: path.path) {
                    paths.append(path)
                }
            }
        }
        
        return paths
    }
    
    func loadUsageData() async -> [UsageEntry] {
        processedHashes.removeAll()
        
        // Collect all JSONL files at once
        let allJSONLFiles = findAllJSONLFiles()
        
        // Load files with parallel processing
        var entries = await withTaskGroup(of: [UsageEntry].self) { group in
            for fileURL in allJSONLFiles {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    return await self.parseJSONLFile(fileURL)
                }
            }
            
            var allEntries: [UsageEntry] = []
            for await fileEntries in group {
                allEntries.append(contentsOf: fileEntries)
            }
            return allEntries
        }
        
        // Sort entries by timestamp in-place and return
        entries.sort { $0.timestamp < $1.timestamp }
        return entries
    }
    
    private func findAllJSONLFiles() -> [URL] {
        var jsonlFiles: [URL] = []
        
        // Only process files modified within the last 24 hours
        let cutoffDate = Date().addingTimeInterval(-24 * 3600) // 24 hours ago
        
        for path in claudePaths {
            if let enumerator = fileManager.enumerator(
                at: path,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    guard fileURL.pathExtension == "jsonl" else { continue }
                    
                    // Check modification time
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                        if let modificationDate = resourceValues.contentModificationDate {
                            // Skip files older than 24 hours
                            if modificationDate > cutoffDate {
                                jsonlFiles.append(fileURL)
                            }
                        }
                    } catch {
                        // If we can't get modification date, include the file to be safe
                        jsonlFiles.append(fileURL)
                    }
                }
            }
        }
        
        return jsonlFiles
    }
    
    private func parseJSONLFile(_ fileURL: URL) async -> [UsageEntry] {
        var entries: [UsageEntry] = []
        
        do {
            // Load as memory-mapped file
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            
            // Process while splitting by newlines
            var currentIndex = data.startIndex
            
            while currentIndex < data.endIndex {
                // Find next newline
                let nextNewline = data[currentIndex...].firstIndex(of: 0x0A) ?? data.endIndex
                
                if nextNewline > currentIndex {
                    let lineData = data[currentIndex..<nextNewline]
                    
                    // Skip empty lines
                    if !lineData.isEmpty {
                        if let entry = parseJSONData(lineData) {
                            // Duplicate check
                            if let hash = entry.uniqueHash {
                                if !processedHashes.contains(hash) {
                                    processedHashes.insert(hash)
                                    entries.append(entry)
                                }
                            } else {
                                entries.append(entry)
                            }
                        }
                    }
                }
                
                currentIndex = nextNewline.advanced(by: 1)
            }
        } catch {
            // Ignore errors and continue
        }
        
        return entries
    }
    
    private func parseJSONData(_ data: Data) -> UsageEntry? {
        // Manually parse JSON (only required fields)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Skip synthetic entries
        if let model = json["model"] as? String, model == "<synthetic>" {
            return nil
        }
        
        // Timestamp (required)
        guard let timestampString = json["timestamp"] as? String else {
            return nil
        }
        
        // Fast date parsing
        guard let finalTimestamp = FastISO8601DateParser.parse(timestampString) else {
            return nil
        }
        
        // Get usage data (minimize nest checking)
        let usage = (json["usage"] as? [String: Any]) ?? 
                   ((json["message"] as? [String: Any])?["usage"] as? [String: Any])
        
        // Token counts (default 0)
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0
        let cacheCreationTokens = usage?["cache_creation_input_tokens"] as? Int ?? 0
        let cacheReadTokens = usage?["cache_read_input_tokens"] as? Int ?? 0
        
        // Model name
        let model = (json["model"] as? String) ?? 
                   ((json["message"] as? [String: Any])?["model"] as? String)
        
        // ID (for duplicate checking)
        let messageId = ((json["message"] as? [String: Any])?["id"] as? String) ?? 
                       (json["message_id"] as? String)
        let requestId = (json["requestId"] as? String) ?? (json["request_id"] as? String)
        
        return UsageEntry(
            timestamp: finalTimestamp,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            model: model,
            messageId: messageId,
            requestId: requestId
        )
    }
}