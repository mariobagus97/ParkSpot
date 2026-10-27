import Testing
@testable import ParkSpot

/// The fakes carry contracts that later tasks assert against, so they get their own checks.
@MainActor struct FakesTests {
    let fix = LocationFix(coordinate: .init(latitude: -6.2, longitude: 106.8), horizontalAccuracy: 8,
                          timestamp: FakeClock().now)

    @Test func openStreamsAreCountedAndReleased() async {
        let location = FakeLocation()
        let fixTask = Task { for await _ in location.fixes() {} }
        let headingTask = Task { for await _ in location.headings() {} }
        await settle()
        #expect(location.subscriberCount == 2)

        fixTask.cancel()
        await settle()
        #expect(location.subscriberCount == 1)

        headingTask.cancel()
        await settle()
        #expect(location.subscriberCount == 0)
    }

    @Test func droppedStreamIsReleased() async {
        let location = FakeLocation()
        _ = location.fixes()
        _ = location.headings()
        await settle()
        #expect(location.subscriberCount == 0)
    }

    @Test func sentFixReachesEveryOpenStream() async {
        let location = FakeLocation()
        let first = Task { () -> LocationFix? in
            for await received in location.fixes() { return received }
            return nil
        }
        let second = Task { () -> LocationFix? in
            for await received in location.fixes() { return received }
            return nil
        }
        await settle()
        location.send(fix)
        #expect(await first.value == fix)
        #expect(await second.value == fix)
    }

    @Test func sentHeadingIncludingNilReachesTheStream() async {
        let location = FakeLocation()
        let task = Task { () -> [Heading?] in
            var received: [Heading?] = []
            for await heading in location.headings() {
                received.append(heading)
                if received.count == 2 { break }
            }
            return received
        }
        await settle()
        location.sendHeading(nil)
        location.sendHeading(Heading(degrees: 90))
        #expect(await task.value == [nil, Heading(degrees: 90)])
    }

    @Test func authorizationRequestIsCounted() async {
        let location = FakeLocation()
        location.authorization = .denied
        let result = await location.requestAuthorization()
        #expect(result == .denied)
        #expect(location.requestCount == 1)
    }

    @Test func testDependenciesShareOneClock() {
        let clock = FakeClock()
        let deps = AppDependencies.test(clock: clock)
        let start = deps.now()
        clock.advance(30)
        #expect(deps.now().timeIntervalSince(start) == 30)
    }

    @Test func testDependenciesComeWithAWorkingRepository() throws {
        let deps = AppDependencies.test()
        let spot = ParkingSpot(createdAt: deps.now(), photoFileName: "a.jpg")
        try deps.repository.insertActive(spot)
        #expect(try deps.repository.activeSpot()?.id == spot.id)
    }
}
