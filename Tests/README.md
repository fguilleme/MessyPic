# Photo analysis checks

Run from the project directory on macOS with Xcode installed:

```sh
xcrun swiftc -module-cache-path /tmp/MessyPicSwiftModuleCache -swift-version 5 MessyPic/PhotoModels.swift MessyPic/PhotoAnalyzer.swift Tests/PhotoAnalyzerChecks.swift -o /tmp/MessyPicPhotoAnalyzerChecks
/tmp/MessyPicPhotoAnalyzerChecks
```

The checks cover subject-mask alignment for portrait and landscape images, invalid-mask fallback, turquoise classification, priority of `night_sky` over generic sky and document labels, and old/new cache decoding.

An optional argument accepts the original 590 × 1280 screenshot of the turquoise dress supplied in this conversation. It crops the photograph in memory and verifies the full Vision pipeline changes its category to Turquoise. Vision must have access to the system model services for this integration check.
