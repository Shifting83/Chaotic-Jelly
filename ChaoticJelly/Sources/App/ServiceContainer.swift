import Foundation
import SwiftData

// MARK: - ServiceContainer

/// Central dependency container. Created once at app launch.
@MainActor
final class ServiceContainer {
    let settings: AppSettings
    let logger: LoggingService
    let processRunner: ProcessRunner
    let toolLocator: ToolLocator
    let ffprobeService: FFprobeService
    let ffmpegService: FFmpegService
    let mkvService: MKVToolNixService
    let scanService: ScanService
    let analysisEngine: AnalysisEngine
    let cacheManager: CacheManager
    let validationService: ValidationService
    let pipeline: ProcessingPipeline
    let jobManager: JobManager
    let updateService: UpdateService
    let arrService: ArrService

    init(modelContext: ModelContext) {
        let settings = AppSettings()
        let logger = LoggingService()
        let processRunner = ProcessRunner()
        let toolLocator = ToolLocator(settings: settings)

        let ffprobeService = FFprobeService(
            processRunner: processRunner,
            toolLocator: toolLocator,
            logger: logger
        )
        let ffmpegService = FFmpegService(
            processRunner: processRunner,
            toolLocator: toolLocator,
            logger: logger
        )
        let mkvService = MKVToolNixService(
            processRunner: processRunner,
            toolLocator: toolLocator,
            logger: logger
        )
        let scanService = ScanService(logger: logger)
        let analysisEngine = AnalysisEngine()
        let cacheManager = CacheManager(settings: settings, logger: logger)
        let validationService = ValidationService(
            ffprobeService: ffprobeService,
            logger: logger
        )
        let pipeline = ProcessingPipeline(
            ffmpegService: ffmpegService,
            mkvService: mkvService,
            validationService: validationService,
            cacheManager: cacheManager,
            logger: logger,
            settings: settings
        )
        let jobManager = JobManager(
            modelContext: modelContext,
            scanService: scanService,
            ffprobeService: ffprobeService,
            analysisEngine: analysisEngine,
            pipeline: pipeline,
            cacheManager: cacheManager,
            logger: logger,
            settings: settings,
            arrService: arrService
        )

        let updateService = UpdateService(settings: settings, logger: logger)
        let arrService = ArrService(settings: settings, logger: logger)

        self.settings = settings
        self.logger = logger
        self.processRunner = processRunner
        self.toolLocator = toolLocator
        self.ffprobeService = ffprobeService
        self.ffmpegService = ffmpegService
        self.mkvService = mkvService
        self.scanService = scanService
        self.analysisEngine = analysisEngine
        self.cacheManager = cacheManager
        self.validationService = validationService
        self.pipeline = pipeline
        self.jobManager = jobManager
        self.updateService = updateService
        self.arrService = arrService
    }
}
