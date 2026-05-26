import Foundation

struct FileOrganizerService {
    private let engine = FileRuleEngine()
    private let trashService = TrashService()

    func candidates(in folderURL: URL) -> [FileCandidate] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { return nil }
            return FileCandidate(url: url, sizeBytes: values?.fileSize.map(Int64.init), modificationDate: values?.contentModificationDate)
        }
    }

    func preview(rule: FileRule, sourceURL: URL, destinationResolver: (UUID) -> URL?) -> [FileRulePreview] {
        engine.preview(rule: rule, candidates: candidates(in: sourceURL), destinationResolver: destinationResolver)
    }

    func apply(previews: [FileRulePreview], rule: FileRule, dryRun: Bool) -> [CommandResult] {
        guard !dryRun, !rule.dryRunOnly else {
            let message = rule.dryRunOnly ? "Dry run is enabled for this rule. No files were changed." : "\(previews.count) item(s) matched."
            return [.success("File Rule Preview", message, details: previews.map { "\($0.fileURL.lastPathComponent): \($0.actionDescription)" })]
        }

        let collisionDetails = destinationCollisionDetails(previews: previews, rule: rule)
        guard collisionDetails.isEmpty else {
            return [.failure("File Rule", "Apply blocked because one or more destinations already exist or repeat.", details: collisionDetails)]
        }

        var results: [CommandResult] = []
        for preview in previews {
            switch rule.action {
            case .moveToFolder:
                guard let destinationURL = preview.destinationURL else {
                    results.append(.failure("Move File", "Missing destination for \(preview.fileURL.lastPathComponent)."))
                    continue
                }
                results.append(move(preview.fileURL, to: destinationURL))
            case .copyToFolder:
                guard let destinationURL = preview.destinationURL else {
                    results.append(.failure("Copy File", "Missing destination for \(preview.fileURL.lastPathComponent)."))
                    continue
                }
                results.append(copy(preview.fileURL, to: destinationURL))
            case .tag:
                results.append(tag(preview.fileURL, actionDescription: preview.actionDescription))
            case .moveToTrash:
                results.append(trashService.moveToTrash(preview.fileURL))
            }
        }
        return results
    }

    private func destinationCollisionDetails(previews: [FileRulePreview], rule: FileRule) -> [String] {
        switch rule.action {
        case .moveToFolder, .copyToFolder:
            break
        case .tag, .moveToTrash:
            return []
        }

        var details: [String] = []
        var destinationCounts: [URL: Int] = [:]
        previews.compactMap(\.destinationURL).forEach { destinationCounts[$0, default: 0] += 1 }

        for preview in previews {
            guard let destinationURL = preview.destinationURL else {
                details.append("Missing destination for \(preview.fileURL.lastPathComponent).")
                continue
            }

            if destinationCounts[destinationURL, default: 0] > 1 {
                details.append("Multiple files would write \(destinationURL.lastPathComponent).")
                continue
            }

            if FileManager.default.fileExists(atPath: destinationURL.path) && destinationURL != preview.fileURL {
                details.append("\(destinationURL.path) already exists.")
            }
        }

        return details
    }

    private func move(_ sourceURL: URL, to destinationURL: URL) -> CommandResult {
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            return .success("Move File", "Moved \(sourceURL.lastPathComponent).")
        } catch {
            return .failure("Move File", "Could not move \(sourceURL.lastPathComponent).", details: [error.localizedDescription])
        }
    }

    private func copy(_ sourceURL: URL, to destinationURL: URL) -> CommandResult {
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return .success("Copy File", "Copied \(sourceURL.lastPathComponent).")
        } catch {
            return .failure("Copy File", "Could not copy \(sourceURL.lastPathComponent).", details: [error.localizedDescription])
        }
    }

    private func tag(_ url: URL, actionDescription: String) -> CommandResult {
        // Finder tags are public resource values, but Finder and iCloud-protected locations can
        // refuse them. Failures are surfaced rather than hidden.
        guard #available(macOS 26.0, *) else {
            return .failure("Finder Tag", "Finder tag writing requires macOS 26 or later in the current SDK.")
        }

        do {
            var resourceValues = URLResourceValues()
            resourceValues.tagNames = [actionDescription.replacingOccurrences(of: "Apply Finder tag ", with: "")]
            var mutableURL = url
            try mutableURL.setResourceValues(resourceValues)
            return .success("Finder Tag", "Tagged \(url.lastPathComponent).")
        } catch {
            return .failure("Finder Tag", "Could not tag \(url.lastPathComponent).", details: [error.localizedDescription])
        }
    }
}
