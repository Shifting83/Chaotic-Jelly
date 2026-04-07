import Foundation

enum Constants {
    static let appName = "Chaotic Jelly"
    static let bundleIdentifier = "com.chaoticjelly.app"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    enum Defaults {
        static let keepLanguages = ["eng"]
        static let maxCacheSizeGB = 50
        static let maxConcurrentFiles = 1
        static let backupRetentionDays = 7
    }

    enum FileSize {
        static let gigabyte: Int64 = 1_073_741_824
        static let megabyte: Int64 = 1_048_576
        static let kilobyte: Int64 = 1_024
    }
}
