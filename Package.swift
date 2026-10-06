// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockChef",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "StockChefCore", targets: ["StockChefCore"])],
    targets: [
        .target(name: "StockChefCore", path: "Sources/StockChefCore"),
        .testTarget(name: "StockChefCoreTests", dependencies: ["StockChefCore"], path: "Tests/StockChefCoreTests")
    ]
)
