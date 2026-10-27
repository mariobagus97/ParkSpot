import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor struct SaveCoordinatorTests {
    let location = FakeLocation()
    let camera = FakeCamera()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    /// Kept for the whole test: a freed container crashes the test host.
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let saver: SpotSaver
    let coordinator: SaveCoordinator

    init() {
        deps = .test(location: location, camera: camera, photos: photos, container: container, clock: clock)
        saver = SpotSaver(deps: deps)
        coordinator = SaveCoordinator(deps: deps, saver: saver)
    }

    /// Stores an earlier, active spot, so the next save has something to replace.
    @discardableResult
    func insertActiveSpot(placeName: String? = nil) throws -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "old.jpg")
        spot.placeName = placeName
        try deps.repository.insertActive(spot)
        return spot
    }

    /// A dropped presentation must never wedge the button: the next tap starts a fresh flow.
    @Test func flowIsUsableAgainAfterAFailedSave() async throws {
        photos.failNextSave = true
        coordinator.start()
        coordinator.photoTaken(.solid())
        await settle()
        #expect(coordinator.alert == .saveFailed)

        photos.failNextSave = false
        coordinator.start()
        await settle()

        #expect(coordinator.cover == .camera)
    }

    @Test func flowIsUsableAgainAfterTheDetailsClose() async throws {
        coordinator.start()
        coordinator.photoTaken(.solid())
        await settle()
        coordinator.detailsDone()

        coordinator.start()
        await settle()

        #expect(coordinator.cover == .camera || coordinator.alert == .confirmReplace)
    }

    @Test func startWithoutActiveOpensCamera() async {
        coordinator.start()
        await settle()

        #expect(coordinator.cover == .camera)
        #expect(coordinator.alert == nil)
        #expect(saver.isRefining)
    }

    @Test func startWithActiveAsksToReplace() async throws {
        try insertActiveSpot(placeName: "Jl. Sudirman")

        coordinator.start()
        await settle()

        #expect(coordinator.alert == .confirmReplace)
        #expect(coordinator.cover == nil)
        #expect(coordinator.replacingPlaceName == "Jl. Sudirman")
        // Nothing is captured before the user agrees.
        #expect(!saver.isRefining)
        #expect(location.subscriberCount == 0)
    }

    @Test func confirmReplaceOpensCamera() async throws {
        try insertActiveSpot()
        coordinator.start()

        coordinator.confirmReplace()
        await settle()

        #expect(coordinator.alert == nil)
        #expect(coordinator.cover == .camera)
        #expect(saver.isRefining)
    }

    @Test func secondStartIsIgnoredWhileFlowRuns() async {
        // Both permissions undecided, so a second flow would show as a second request (the fakes count them).
        location.authorization = .notDetermined
        camera.statusValue = .notDetermined

        coordinator.start()
        coordinator.start()
        await settle()

        #expect(location.subscriberCount == 1)
        #expect(coordinator.cover == .camera)
        #expect(location.requestCount == 1)
        #expect(camera.requestCount == 1)
    }

    @Test func secondStartIsIgnoredWhileTheDetailsShow() async throws {
        coordinator.start()
        coordinator.photoTaken(.solid())
        let spotID = try #require(coordinator.detailsSpotID)

        // The photo is stored, so a second flow would see an active spot and ask to replace it over the sheet.
        coordinator.start()
        await settle()

        #expect(coordinator.alert == nil)
        #expect(coordinator.cover == nil)
        #expect(coordinator.detailsSpotID == spotID)
    }

    @Test func secondStartIsIgnoredWhileThePhotoAlertShows() async {
        coordinator.start()
        coordinator.cameraCancelled()

        // A second flow would reopen the camera under the "photo needed" alert.
        coordinator.start()
        await settle()

        #expect(coordinator.cover == nil)
        #expect(coordinator.alert == .photoRequired)
    }

    @Test func secondStartIsIgnoredWhileReplaceAlertShows() async throws {
        try insertActiveSpot()

        coordinator.start()
        coordinator.start()
        coordinator.confirmReplace()
        await settle()

        #expect(location.subscriberCount == 1)
        #expect(coordinator.cover == .camera)
    }

    @Test func cameraDeniedShowsDeniedScreen() async {
        camera.statusValue = .denied

        coordinator.start()
        await settle()

        #expect(coordinator.cover == .cameraDenied)
        #expect(!saver.isRefining)
    }

    @Test func notDeterminedCameraIsRequestedThenOpens() async {
        camera.statusValue = .notDetermined
        camera.requestResult = true

        coordinator.start()
        await settle()

        #expect(camera.requestCount == 1)
        #expect(coordinator.cover == .camera)
        #expect(saver.isRefining)
    }

    @Test func notDeterminedCameraRefusedShowsDeniedScreen() async {
        camera.statusValue = .notDetermined
        camera.requestResult = false

        coordinator.start()
        await settle()

        #expect(camera.requestCount == 1)
        #expect(coordinator.cover == .cameraDenied)
        #expect(!saver.isRefining)
    }

    @Test func unavailableCameraUsesStandInInDebugOnly() async {
        camera.statusValue = .unavailable

        coordinator.start()
        await settle()

        #if DEBUG
        #expect(coordinator.cover == .camera)
        #expect(saver.isRefining)
        #else
        #expect(coordinator.cover == .cameraDenied)
        #expect(!saver.isRefining)
        #endif
    }

    @Test func notDeterminedLocationIsRequested() async {
        location.authorization = .notDetermined

        coordinator.start()
        await settle()

        #expect(location.requestCount == 1)
        // The camera does not wait for the answer.
        #expect(coordinator.cover == .camera)
    }

    @Test func determinedLocationIsNotRequested() async {
        coordinator.start()
        await settle()

        #expect(location.requestCount == 0)
    }

    @Test func cameraCancelledAsksForPhoto() async throws {
        coordinator.start()

        coordinator.cameraCancelled()
        await settle()

        #expect(coordinator.alert == .photoRequired)
        #expect(coordinator.cover == nil)
        let spots = try deps.repository.allSpots()
        #expect(spots.isEmpty)
        #expect(saver.isRefining)
    }

    @Test func cancelAfterPhotoRequiredStopsCapture() async {
        coordinator.start()
        coordinator.cameraCancelled()

        coordinator.cancel()
        await settle()

        #expect(!saver.isRefining)
        #expect(coordinator.alert == nil)
        #expect(coordinator.cover == nil)
        #expect(location.subscriberCount == 0)
    }

    @Test func cancelClosesDeniedScreenAndAllowsANewStart() async {
        camera.statusValue = .denied
        coordinator.start()

        coordinator.cancel()
        #expect(coordinator.cover == nil)

        camera.statusValue = .authorized
        coordinator.start()
        await settle()
        #expect(coordinator.cover == .camera)
    }

    @Test func retakeReopensCamera() async {
        coordinator.start()
        coordinator.cameraCancelled()

        coordinator.retakePhoto()
        await settle()

        #expect(coordinator.cover == .camera)
        #expect(coordinator.alert == nil)
        #expect(saver.isRefining)
    }

    @Test func photoTakenOpensDetails() async throws {
        let saved = Received()
        coordinator.onSaved = { saved.ids.append($0) }
        coordinator.start()

        coordinator.photoTaken(.solid())
        await settle()

        let active = try #require(try deps.repository.activeSpot())
        #expect(coordinator.detailsSpotID == active.id)
        #expect(saved.ids == [active.id])
        #expect(coordinator.cover == nil)
        #expect(coordinator.alert == nil)
    }

    @Test func photoSaveFailureShowsAlert() async throws {
        let saved = Received()
        coordinator.onSaved = { saved.ids.append($0) }
        photos.failNextSave = true
        coordinator.start()

        coordinator.photoTaken(.solid())
        await settle()

        #expect(coordinator.alert == .saveFailed)
        #expect(coordinator.cover == nil)
        #expect(coordinator.detailsSpotID == nil)
        #expect(saved.ids.isEmpty)
        let spots = try deps.repository.allSpots()
        #expect(spots.isEmpty)
        #expect(!saver.isRefining)
    }

    @Test func dismissingSaveFailedEndsTheFlow() async {
        photos.failNextSave = true
        coordinator.start()
        coordinator.photoTaken(.solid())

        coordinator.cancel()
        #expect(coordinator.alert == nil)

        coordinator.start()
        await settle()
        #expect(coordinator.cover == .camera)
    }

    @Test func detailsDoneEndsTheFlowButKeepsRefining() async throws {
        coordinator.start()
        coordinator.photoTaken(.solid())

        coordinator.detailsDone()
        await settle()

        #expect(coordinator.detailsSpotID == nil)
        // The saved spot keeps sharpening in the background.
        #expect(saver.isRefining)

        // The flow is over: the next start sees the saved spot and asks before replacing it.
        coordinator.start()
        #expect(coordinator.alert == .confirmReplace)
    }
}

/// Collects the ids `onSaved` reports.
@MainActor final class Received {
    var ids: [UUID] = []
}
