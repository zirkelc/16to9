/**
 Decides when the app shows its tour at launch: while the app cannot control windows, so that the user can give the
 permission, and at the first launch of each version, so that the user sees what is new.
 */
public enum TourPolicy {
  // The versions are build numbers. Nil means that no version showed the tour yet.
  public static func showsAtLaunch(isPermissionGranted: Bool, lastTourVersion: String?, currentVersion: String) -> Bool {
    !isPermissionGranted || lastTourVersion != currentVersion
  }
}
