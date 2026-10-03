import Foundation

/// Appends to ~/Library/Logs/PreflopCoach.log so problems can be diagnosed after the fact.
enum Log {
    static let file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/PreflopCoach.log")

    private static let queue = DispatchQueue(label: "PreflopCoach.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "\(stamp.string(from: Date())) \(message)\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: file) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                handle.closeFile()
            } else {
                try? Data(line.utf8).write(to: file)
            }
        }
    }
}
