// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Wallflow",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Wallflow", targets: ["Wallflow"])
  ],
  targets: [
    .executableTarget(
      name: "Wallflow",
      path: "Sources/Wallflow"
    ),
    .testTarget(
      name: "WallflowTests",
      dependencies: ["Wallflow"],
      path: "Tests/WallflowTests"
    ),
  ],
  swiftLanguageModes: [.v5]
)
