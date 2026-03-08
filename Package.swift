// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenClark",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "OpenClark",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "OpenClark"
        ),
    ]
)
