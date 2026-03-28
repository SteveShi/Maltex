//
//  Updater.swift
//  Maltex
//
//  Created for Sparkle Integration.
//

import Foundation
import os.log
import Sparkle
import SwiftUI
import Combine

final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let logger = Logger(subsystem: "app.maltex.native", category: "Sparkle")

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        logError("Update aborted", error: error)
    }

    func updater(_ updater: SPUUpdater, didFailToUpdateWithError error: Error) {
        logError("Update failed", error: error)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.versionString
        let shortVersion = item.displayVersionString
        logger.info("Found valid update: version=\(version, privacy: .public), shortVersion=\(shortVersion, privacy: .public)")
    }

    private func logError(_ message: String, error: Error) {
        let nsError = error as NSError
        logger.error("\(message, privacy: .public): \(nsError.localizedDescription, privacy: .public) (domain=\(nsError.domain, privacy: .public), code=\(nsError.code, privacy: .public))")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            logger.error("Underlying error: \(underlying.localizedDescription, privacy: .public) (domain=\(underlying.domain, privacy: .public), code=\(underlying.code, privacy: .public))")
        }
    }
}

/// A wrapper around Sparkle's SPUStandardUpdaterController
@MainActor
class Updater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    private let sparkleDelegate = SparkleUpdaterDelegate()
    
    @Published var canCheckForUpdates = false

    init() {
        // Initialize Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: sparkleDelegate, userDriverDelegate: nil)
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
