import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor struct SpotDetailsViewModelTests {
    let location = FakeLocation()
    let clock = FakeClock()
    /// Kept for the whole test: a freed container crashes the test host.
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let saver: SpotSaver
    let spot: ParkingSpot
    let vm: SpotDetailsViewModel

    init() throws {
        // Only `done()`'s own save may reach the store: autosave would hide a missing one.
        container.mainContext.autosaveEnabled = false
        deps = .test(location: location, container: container, clock: clock)
        saver = SpotSaver(deps: deps)
        spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        try deps.repository.insertActive(spot)
        vm = SpotDetailsViewModel(spot: spot, saver: saver, repository: deps.repository, location: location)
    }

    /// The spot as the store holds it, read through a fresh context so unsaved changes stay invisible.
    func stored() throws -> ParkingSpot? {
        let id = spot.id
        return try ModelContext(container).fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.id == id })).first
    }

    func fix(_ accuracy: Double) -> LocationFix {
        LocationFix(coordinate: Coordinate(latitude: -6.2, longitude: 106.8174),
                    horizontalAccuracy: accuracy,
                    timestamp: clock.now)
    }

    @Test func quickFloorsAndLimit() {
        #expect(SpotDetailsViewModel.quickFloors == ["B3", "B2", "B1", "G", "1", "2"])
        #expect(SpotDetailsViewModel.noteLimit == 140)
    }

    @Test func noteIsCappedAt140() {
        vm.note = String(repeating: "a", count: 200)
        #expect(vm.note.count == 140)
    }

    @Test func noteKeepsTheFirst140Characters() {
        let first = String(repeating: "a", count: 139)
        vm.note = first + "bcd"
        #expect(vm.note == first + "b")
    }

    @Test func noteUnderTheLimitIsUntouched() {
        vm.note = "Near the blue elevator"
        #expect(vm.note == "Near the blue elevator")
    }

    @Test func selectingAFloorSetsIt() {
        vm.selectFloor("B2")
        #expect(vm.floor == "B2")
        vm.selectFloor("G")
        #expect(vm.floor == "G")
    }

    @Test func selectingSameFloorClears() {
        vm.selectFloor("B2")
        vm.selectFloor("B2")
        #expect(vm.floor == nil)
    }

    @Test func typedFloorIsTrimmedAndBlankClears() {
        vm.setTypedFloor("  P5 ")
        #expect(vm.floor == "P5")
        vm.setTypedFloor("Rooftop")
        #expect(vm.floor == "Rooftop")
        vm.setTypedFloor("   ")
        #expect(vm.floor == nil)
    }

    @Test func doneSavesFloorAndNote() throws {
        vm.selectFloor("B2")
        vm.note = "Near the blue elevator"

        try vm.done()

        #expect(spot.floor == "B2")
        #expect(spot.note == "Near the blue elevator")
        let reread = try #require(try stored())
        #expect(reread.floor == "B2")
        #expect(reread.note == "Near the blue elevator")
    }

    @Test func doneWithoutFloorLeavesNoFloor() throws {
        try vm.done()
        #expect(spot.floor == nil)
        let reread = try #require(try stored())
        #expect(reread.floor == nil)
    }

    @Test func blankNoteSavesNil() throws {
        spot.note = "old"
        vm.note = "   "

        try vm.done()

        #expect(spot.note == nil)
        let reread = try #require(try stored())
        #expect(reread.note == nil)
    }

    @Test func noteIsSavedTrimmed() throws {
        vm.note = "  level 2, by the stairs \n"
        try vm.done()
        #expect(spot.note == "level 2, by the stairs")
    }

    @Test func startsFromTheSpotsFloorAndNote() {
        spot.floor = "B1"
        spot.note = "pillar 7"
        let again = SpotDetailsViewModel(spot: spot, saver: saver, repository: deps.repository, location: location)
        #expect(again.floor == "B1")
        #expect(again.note == "pillar 7")
    }

    @Test func deniedLocationShowsNote() {
        #expect(!vm.locationOff)
        location.authorization = .denied
        #expect(vm.locationOff)
    }

    @Test func notDeterminedLocationDoesNotShowNote() {
        location.authorization = .notDetermined
        #expect(!vm.locationOff)
    }

    @Test func refiningTextShowsTheCurrentAccuracy() async {
        saver.beginCapture()
        location.send(fix(35))   // above 20 m, so the position is still being sharpened
        await settle()
        #expect(saver.isRefining)

        let text = vm.refiningText
        #expect(text == String(format: String(localized: "improving_fmt"), Formatting.accuracy(35, locale: .current)))
        #expect(text?.contains("35") == true)
        #expect(text?.contains("improving_fmt") == false)   // the key is translated
    }

    @Test func refiningTextWaitsForTheFirstFix() async {
        saver.beginCapture()
        await settle()
        #expect(saver.isRefining)
        #expect(vm.refiningText == nil)
    }

    @Test func refiningTextIsNilOnceRefiningStops() async {
        saver.beginCapture()
        location.send(fix(35))
        await settle()
        #expect(vm.refiningText != nil)

        saver.stopRefining()
        #expect(vm.refiningText == nil)
    }

    @Test func refiningTextIsNilWhileLocationIsOff() async {
        saver.beginCapture()
        location.send(fix(35))
        await settle()
        location.authorization = .denied
        #expect(vm.refiningText == nil)
    }
}
