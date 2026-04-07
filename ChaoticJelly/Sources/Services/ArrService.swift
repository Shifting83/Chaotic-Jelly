import Foundation

// MARK: - ArrService

/// Communicates with Sonarr and Radarr to handle corrupt files:
/// identifies the media, deletes the corrupt file, and triggers re-download.
actor ArrService {
    private let settings: AppSettings
    private let logger: LoggingService

    init(settings: AppSettings, logger: LoggingService) {
        self.settings = settings
        self.logger = logger
    }

    /// Handle a corrupt file: try each enabled *arr instance to identify it,
    /// delete the corrupt file, and trigger a re-download.
    /// `selectedInstanceIds` limits which instances to use (nil = all enabled).
    func handleCorruptFile(at path: String, fileName: String, selectedInstanceIds: Set<UUID>? = nil) async -> Bool {
        let instances = settings.arrInstances.filter { instance in
            instance.isEnabled &&
            !instance.url.isEmpty &&
            !instance.apiKey.isEmpty &&
            (selectedInstanceIds == nil || selectedInstanceIds!.contains(instance.id))
        }

        // Try Sonarr instances first, then Radarr
        let sonarrInstances = instances.filter { $0.type == .sonarr }
        let radarrInstances = instances.filter { $0.type == .radarr }

        for instance in sonarrInstances {
            if let result = await handleViaSonarr(baseURL: instance.baseURL, apiKey: instance.apiKey, path: path, fileName: fileName) {
                return result
            }
        }

        for instance in radarrInstances {
            if let result = await handleViaRadarr(baseURL: instance.baseURL, apiKey: instance.apiKey, path: path, fileName: fileName) {
                return result
            }
        }

        await logger.logWarning("No *arr service matched for corrupt file: \(fileName)")
        return false
    }

    // MARK: - Sonarr

    private func handleViaSonarr(baseURL: String, apiKey: String, path: String, fileName: String) async -> Bool? {
        // 1. Parse filename to identify the episode
        guard let parsed = await parseTitle(baseURL: baseURL, apiKey: apiKey, title: fileName) else {
            return nil  // Not recognized by Sonarr — try Radarr
        }

        guard let seriesDict = parsed["series"] as? [String: Any],
              let seriesId = seriesDict["id"] as? Int else {
            return nil
        }

        await logger.logInfo("Sonarr identified: \(seriesDict["title"] as? String ?? "unknown") — looking up episode file...")

        // 2. Find the episode file by matching path
        guard let episodeFileId = await findEpisodeFile(baseURL: baseURL, apiKey: apiKey, seriesId: seriesId, filePath: path) else {
            await logger.logWarning("Sonarr: could not find episode file record for \(fileName)")
            return nil
        }

        // 3. Find the episode ID for the re-download search
        let episodeId = await findEpisodeId(baseURL: baseURL, apiKey: apiKey, episodeFileId: episodeFileId)

        // 4. Delete the episode file via Sonarr
        let deleted = await deleteEpisodeFile(baseURL: baseURL, apiKey: apiKey, fileId: episodeFileId)
        guard deleted else {
            await logger.logError("Sonarr: failed to delete episode file \(episodeFileId)")
            return false
        }

        await logger.logInfo("Sonarr: deleted corrupt file \(fileName)")

        // 5. Trigger episode search for re-download
        if let epId = episodeId {
            let searched = await triggerEpisodeSearch(baseURL: baseURL, apiKey: apiKey, episodeIds: [epId])
            if searched {
                await logger.logInfo("Sonarr: triggered re-download search for episode \(epId)")
            }
        }

        return true
    }

    private func findEpisodeFile(baseURL: String, apiKey: String, seriesId: Int, filePath: String) async -> Int? {
        guard let data = await arrGet(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/episodefile?seriesId=\(seriesId)") else {
            return nil
        }
        guard let files = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        // Match by file path
        for file in files {
            if let fp = file["path"] as? String, fp == filePath {
                return file["id"] as? Int
            }
        }
        // Fallback: match by filename
        let targetName = URL(fileURLWithPath: filePath).lastPathComponent
        for file in files {
            if let fp = file["path"] as? String,
               URL(fileURLWithPath: fp).lastPathComponent == targetName {
                return file["id"] as? Int
            }
        }
        return nil
    }

    private func findEpisodeId(baseURL: String, apiKey: String, episodeFileId: Int) async -> Int? {
        guard let data = await arrGet(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/episode?episodeFileId=\(episodeFileId)") else {
            return nil
        }
        guard let episodes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = episodes.first else {
            return nil
        }
        return first["id"] as? Int
    }

    private func deleteEpisodeFile(baseURL: String, apiKey: String, fileId: Int) async -> Bool {
        return await arrDelete(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/episodefile/\(fileId)")
    }

    private func triggerEpisodeSearch(baseURL: String, apiKey: String, episodeIds: [Int]) async -> Bool {
        let body: [String: Any] = ["name": "EpisodeSearch", "episodeIds": episodeIds]
        return await arrPost(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/command", body: body)
    }

    // MARK: - Radarr

    private func handleViaRadarr(baseURL: String, apiKey: String, path: String, fileName: String) async -> Bool? {
        // 1. Parse filename to identify the movie
        guard let parsed = await parseTitle(baseURL: baseURL, apiKey: apiKey, title: fileName) else {
            return nil
        }

        guard let movieDict = parsed["movie"] as? [String: Any],
              let movieId = movieDict["id"] as? Int else {
            return nil
        }

        let movieTitle = movieDict["title"] as? String ?? "unknown"
        await logger.logInfo("Radarr identified: \(movieTitle) — looking up movie file...")

        // 2. Find the movie file
        guard let movieFileId = await findMovieFile(baseURL: baseURL, apiKey: apiKey, movieId: movieId, filePath: path) else {
            await logger.logWarning("Radarr: could not find movie file record for \(fileName)")
            return nil
        }

        // 3. Delete the movie file via Radarr
        let deleted = await arrDelete(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/moviefile/\(movieFileId)")
        guard deleted else {
            await logger.logError("Radarr: failed to delete movie file \(movieFileId)")
            return false
        }

        await logger.logInfo("Radarr: deleted corrupt file \(fileName)")

        // 4. Trigger movie search for re-download
        let body: [String: Any] = ["name": "MoviesSearch", "movieIds": [movieId]]
        let searched = await arrPost(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/command", body: body)
        if searched {
            await logger.logInfo("Radarr: triggered re-download search for \(movieTitle)")
        }

        return true
    }

    private func findMovieFile(baseURL: String, apiKey: String, movieId: Int, filePath: String) async -> Int? {
        guard let data = await arrGet(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/moviefile?movieId=\(movieId)") else {
            return nil
        }
        guard let files = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        for file in files {
            if let fp = file["path"] as? String, fp == filePath {
                return file["id"] as? Int
            }
        }
        let targetName = URL(fileURLWithPath: filePath).lastPathComponent
        for file in files {
            if let fp = file["path"] as? String,
               URL(fileURLWithPath: fp).lastPathComponent == targetName {
                return file["id"] as? Int
            }
        }
        return nil
    }

    // MARK: - Shared API

    private func parseTitle(baseURL: String, apiKey: String, title: String) async -> [String: Any]? {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        guard let data = await arrGet(baseURL: baseURL, apiKey: apiKey, endpoint: "/api/v3/parse?title=\(encoded)") else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func arrGet(baseURL: String, apiKey: String, endpoint: String) async -> Data? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            await logger.logError("*arr API GET failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func arrDelete(baseURL: String, apiKey: String, endpoint: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 15
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private func arrPost(baseURL: String, apiKey: String, endpoint: String, body: [String: Any]) async -> Bool {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Connection Test

    /// Test connectivity to Sonarr or Radarr.
    func testConnection(baseURL: String, apiKey: String) async -> (success: Bool, message: String) {
        let url = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let data = await arrGet(baseURL: url, apiKey: apiKey, endpoint: "/api/v3/system/status") else {
            return (false, "Connection failed — check URL and API key")
        }
        guard let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = status["version"] as? String else {
            return (false, "Unexpected response — is this a Sonarr/Radarr server?")
        }
        let appName = status["appName"] as? String ?? "Unknown"
        return (true, "\(appName) v\(version)")
    }
}
