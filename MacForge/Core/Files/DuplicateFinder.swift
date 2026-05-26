import CryptoKit
import Foundation

struct DuplicateFile: Identifiable, Hashable {
    var id = UUID()
    var url: URL
    var sizeBytes: Int64
    var hash: String
}

struct DuplicateGroup: Identifiable, Hashable {
    var id = UUID()
    var sizeBytes: Int64
    var hash: String
    var files: [DuplicateFile]
}

struct DuplicateFinder {
    func findDuplicates(in folderURL: URL) async -> [DuplicateGroup] {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
            guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                return []
            }

            var bySize: [Int64: [URL]] = [:]
            for case let url as URL in enumerator {
                let values = try? url.resourceValues(forKeys: keys)
                guard values?.isRegularFile == true, let fileSize = values?.fileSize else { continue }
                bySize[Int64(fileSize), default: []].append(url)
            }

            var groups: [DuplicateGroup] = []
            for (size, urls) in bySize where urls.count > 1 {
                var byHash: [String: [DuplicateFile]] = [:]
                for url in urls {
                    guard let hash = sha256(url: url) else { continue }
                    byHash[hash, default: []].append(DuplicateFile(url: url, sizeBytes: size, hash: hash))
                }
                for (hash, files) in byHash where files.count > 1 {
                    groups.append(DuplicateGroup(sizeBytes: size, hash: hash, files: files))
                }
            }
            return groups.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value
    }

    private func sha256(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
