import Foundation
import SwiftUI

// MARK: - AppSettings

/// App settings backed by UserDefaults with @Observable support.
/// Uses stored properties with didSet to write through to UserDefaults,
/// ensuring @Observable tracking fires correctly.
@Observable
final class AppSettings: @unchecked Sendable {

    // MARK: Language Settings

    var keepLanguages: [String] = UserDefaults.standard.stringArray(forKey: Keys.keepLanguages) ?? ["eng"] {
        didSet { UserDefaults.standard.set(keepLanguages, forKey: Keys.keepLanguages) }
    }

    var removeSubtitles: Bool = UserDefaults.standard.bool(forKey: Keys.removeSubtitles, default: true) {
        didSet { UserDefaults.standard.set(removeSubtitles, forKey: Keys.removeSubtitles) }
    }

    var removeAudio: Bool = UserDefaults.standard.bool(forKey: Keys.removeAudio, default: false) {
        didSet { UserDefaults.standard.set(removeAudio, forKey: Keys.removeAudio) }
    }

    var conservativeMode: Bool = UserDefaults.standard.bool(forKey: Keys.conservativeMode, default: true) {
        didSet { UserDefaults.standard.set(conservativeMode, forKey: Keys.conservativeMode) }
    }

    var preserveForced: Bool = UserDefaults.standard.bool(forKey: Keys.preserveForced, default: true) {
        didSet { UserDefaults.standard.set(preserveForced, forKey: Keys.preserveForced) }
    }

    var preserveSDH: Bool = UserDefaults.standard.bool(forKey: Keys.preserveSDH, default: false) {
        didSet { UserDefaults.standard.set(preserveSDH, forKey: Keys.preserveSDH) }
    }

    var preserveCommentary: Bool = UserDefaults.standard.bool(forKey: Keys.preserveCommentary, default: false) {
        didSet { UserDefaults.standard.set(preserveCommentary, forKey: Keys.preserveCommentary) }
    }

    // MARK: Jellyfin Settings

    var optimizeForJellyfin: Bool = UserDefaults.standard.bool(forKey: Keys.optimizeForJellyfin) {
        didSet { UserDefaults.standard.set(optimizeForJellyfin, forKey: Keys.optimizeForJellyfin) }
    }

    var jellyfinProfileRaw: String = UserDefaults.standard.string(forKey: Keys.jellyfinProfile) ?? JellyfinProfile.broad.rawValue {
        didSet { UserDefaults.standard.set(jellyfinProfileRaw, forKey: Keys.jellyfinProfile) }
    }

    var jellyfinProfile: JellyfinProfile {
        get { JellyfinProfile(rawValue: jellyfinProfileRaw) ?? .broad }
        set { jellyfinProfileRaw = newValue.rawValue }
    }

    // MARK: Processing Settings

    var cachePathString: String = UserDefaults.standard.string(forKey: Keys.cachePath) ?? AppSettings.defaultCachePath.path {
        didSet { UserDefaults.standard.set(cachePathString, forKey: Keys.cachePath) }
    }

    var cachePath: URL {
        get { URL(fileURLWithPath: cachePathString) }
        set { cachePathString = newValue.path }
    }

    var maxCacheSizeGB: Int = UserDefaults.standard.integer(forKey: Keys.maxCacheSizeGB, default: 50) {
        didSet { UserDefaults.standard.set(maxCacheSizeGB, forKey: Keys.maxCacheSizeGB) }
    }

    var maxCacheSizeBytes: Int64 {
        Int64(maxCacheSizeGB) * 1_073_741_824
    }

    var maxConcurrentFiles: Int = UserDefaults.standard.integer(forKey: Keys.maxConcurrentFiles, default: 1) {
        didSet { UserDefaults.standard.set(maxConcurrentFiles, forKey: Keys.maxConcurrentFiles) }
    }

    var createBackup: Bool = UserDefaults.standard.bool(forKey: Keys.createBackup, default: true) {
        didSet { UserDefaults.standard.set(createBackup, forKey: Keys.createBackup) }
    }

    var backupRetentionDays: Int = UserDefaults.standard.integer(forKey: Keys.backupRetentionDays, default: 7) {
        didSet { UserDefaults.standard.set(backupRetentionDays, forKey: Keys.backupRetentionDays) }
    }

    var overwriteBehaviorRaw: String = UserDefaults.standard.string(forKey: Keys.overwriteBehavior) ?? OverwriteBehavior.confirmEach.rawValue {
        didSet { UserDefaults.standard.set(overwriteBehaviorRaw, forKey: Keys.overwriteBehavior) }
    }

    var overwriteBehavior: OverwriteBehavior {
        get { OverwriteBehavior(rawValue: overwriteBehaviorRaw) ?? .confirmEach }
        set { overwriteBehaviorRaw = newValue.rawValue }
    }

    // MARK: Tool Paths

    var ffmpegPath: String = UserDefaults.standard.string(forKey: Keys.ffmpegPath) ?? "" {
        didSet { UserDefaults.standard.set(ffmpegPath, forKey: Keys.ffmpegPath) }
    }

    var ffprobePath: String = UserDefaults.standard.string(forKey: Keys.ffprobePath) ?? "" {
        didSet { UserDefaults.standard.set(ffprobePath, forKey: Keys.ffprobePath) }
    }

    var mkvmergePath: String = UserDefaults.standard.string(forKey: Keys.mkvmergePath) ?? "" {
        didSet { UserDefaults.standard.set(mkvmergePath, forKey: Keys.mkvmergePath) }
    }

    // MARK: LLM Settings

    var llmEnabled: Bool = UserDefaults.standard.bool(forKey: Keys.llmEnabled) {
        didSet { UserDefaults.standard.set(llmEnabled, forKey: Keys.llmEnabled) }
    }

    var llmProvider: String = UserDefaults.standard.string(forKey: Keys.llmProvider) ?? "anthropic" {
        didSet { UserDefaults.standard.set(llmProvider, forKey: Keys.llmProvider) }
    }

    // MARK: Update Settings

    var checkForUpdates: Bool = UserDefaults.standard.bool(forKey: Keys.checkForUpdates, default: true) {
        didSet { UserDefaults.standard.set(checkForUpdates, forKey: Keys.checkForUpdates) }
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
