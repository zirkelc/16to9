import Testing

@testable import ResizerCore

@Suite("TourPolicy")
struct TourPolicyTests {
  @Test("shows the tour at the first launch")
  func firstLaunch() {
    // Act
    let shows = TourPolicy.showsAtLaunch(isPermissionGranted: true, lastTourVersion: nil, currentVersion: "2")

    // Assert
    #expect(shows)
  }

  @Test("shows the tour when the permission is missing, also for a version that showed it")
  func missingPermission() {
    // Act
    let shows = TourPolicy.showsAtLaunch(isPermissionGranted: false, lastTourVersion: "2", currentVersion: "2")

    // Assert
    #expect(shows)
  }

  @Test("shows the tour at the first launch of a new version")
  func newVersion() {
    // Act
    let shows = TourPolicy.showsAtLaunch(isPermissionGranted: true, lastTourVersion: "1", currentVersion: "2")

    // Assert
    #expect(shows)
  }

  @Test("does not show the tour again for the same version with the permission")
  func sameVersionWithPermission() {
    // Act
    let shows = TourPolicy.showsAtLaunch(isPermissionGranted: true, lastTourVersion: "2", currentVersion: "2")

    // Assert
    #expect(!shows)
  }
}
