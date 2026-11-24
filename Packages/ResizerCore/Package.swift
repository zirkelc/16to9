// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ResizerCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "ResizerCore", targets: ["ResizerCore"])
  ],
  targets: [
    .target(name: "ResizerCore"),
    .testTarget(name: "ResizerCoreTests", dependencies: ["ResizerCore"]),
  ]
)
