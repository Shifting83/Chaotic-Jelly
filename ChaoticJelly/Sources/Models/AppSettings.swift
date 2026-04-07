import Foundation
import SwiftUI

// MARK: - AppSettings

@Observable
final class AppSettings {
    // MARK: Language Settings

    var keepLanguages: [String] {
        get { UserDefaults.standard.stringArray(forKey: Keys.keepLanguages) ?? ["eng"] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.keepLanguages) }
    }

    var removeSubtitles: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.removeSubtitles, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.removeSubtitles) }
    }

    var removeAudio: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.removeAudio, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.removeAudio) }
    }

    var conservativeMode: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.conservativeMode, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.conservativeMode) }
    }

    var preserveForced: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.preserveForced, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.preserveForced) }
    }

    var preserveSDH: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.preserveSDH, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.preserveSDH) }
    }

    var preserveCommentary: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.preserveCommentary, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.preserveCommentary) }
    }

    // MARK: Jellyfin Settings

    var optimizeForJellyfin: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.optimizeForJellyfin) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.optimizeForJellyfin) }
    }

    var jellyfinProfile: JellyfinProfile {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.jellyfinProfile) ?? ""
            return JellyfinProfile(rawValue: raw) ?? .broad
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.jellyfinProfile) }
    }

    // MARK: Processing Settings

    var cachePath: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: Keys.cachePath) {
                return URL(fileURLWithPath: path)
            }
            return Self.defaultCachePath
        }
        set { UserDefaults.standard.set(newValue.path, forKey: Keys.cachePath) }
    }

    var maxCacheSizeGB: Int {
        get { UserDefaults.standard.integer(forKey: Keys.maxCacheSizeGB, default: 50) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.maxCacheSizeGB) }
    }

    var maxCacheSizeBytes: Int64 {
        Int64(maxCacheSizeGB) * 1_073_741_824
    }

    var maxConcurrentFiles: Int {
        get { UserDefaults.standard.integer(forKey: Keys.maxConcurrentFiles, default: 1) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.maxConcurrentFiles) }
    }

    var createBackup: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.createBackup, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.createBackup) }
    }

    var backupRetentionDays: Int {
        get { UserDefaults.standard.integer(forKey: Keys.backupRetentionDays, default: 7) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.backupRetentionDays) }
    }

    var overwriteBehavior: OverwriteBehavior {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.overwriteBehavior) ?? ""
            return OverwriteBehavior(rawValue: raw) ?? .confirmEach
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.overwriteBehavior) }
    }

    // MARK: Tool Paths

    var ffmpegPath: String {
        get { UserDefaults.standard.string(forKey: Keys.ffmpegPath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.ffmpegPath) }
    }

    var ffprobePath: String {
        get { UserDefaults.standard.string(forKey: Keys.ffprobePath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.ffprobePath) }
    }

    var mkvmergePath: String {
        get { UserDefaults.standard.string(forKey: Keys.mkvmergePath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.mkvmergePath) }
    }

    // MARK: LLM Settings

    var llmEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.llmEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.llmEnabled) }
    }

    var llmProvider: String {
        get { UserDefaults.standard.string(forKey: Keys.llmProvider) ?? "anthropic" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.llmProvider) }
    }

    // MARK: Update Settings

    var checkForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.checkForUpdates, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.checkForUpdates) }
    }

    // MARK: Helpers

    static var defaultCachePath: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("com.chaoticjelly.app/WorkingCache", isDirectory: true)
    }

    /// Create a snapshot of current settings for persisting with a job.
    func makeJobSettings(processingMode: ProcessingMode, dryRun: Bool) -> JobSettings {
        JobSettings(
            keepLanguages: keepLanguages,
            removeSubtitles: processingMode.removesSubtitles,
            removeAudio: processingMode.removesAudio,
            conservativeMode: conservativeMode,
            preserveForced: preserveForced,
            preserveSDH: preserveSDH,
            preserveCommentary: preserveCommentary,
            optimizeForJellyfin: optimizeForJellyfin,
            jellyfinProfile: jellyfinProfile,
            createBackup: createBackup,
            dryRun: dryRun
        )
    }

    // MARK: Keys

    private enum Keys {
        static let keepLanguages = "settings.keepLanguages"
        static let removeSubtitles = "settings.removeSubtitles"
        static let removeAudio = "settings.removeAudio"
        static let conservativeMode = "settings.conservativeMode"
        static let preserveForced = "settings.preserveForced"
        static let preserveSDH = "settings.preserveSDH"
        static let preserveCommentary = "settings.preserveCommentary"
        static let optimizeForJellyfin = "settings.optimizeForJellyfin"
        static let jellyfinProfile = "settings.jellyfinProfile"
        static let cachePath = "settings.cachePath"
        static let maxCacheSizeGB = "settings.maxCacheSizeGB"
        static let maxConcurrentFiles = "settings.maxConcurrentFiles"
        static let createBackup = "settings.createBackup"
        static let backupRetentionDays = "settings.backupRetentionDays"
        static let overwriteBehavior = "settings.overwriteBehavior"
        static let ffmpegPath = "settings.ffmpegPath"
        static let ffprobePath = "settings.ffprobePath"
        static let mkvmergePath = "settings.mkvmergePath"
        static let llmEnabled = "settings.llmEnabled"
        static let llmProvider = "settings.llmProvider"
        static let checkForUpdates = "settings.checkForUpdates"
    }
}

// MARK: - UserDefaults Helpers

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }

    func integer(forKey key: String, default defaultValue: Int) -> Int {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return integer(forKey: key)
    }
}
