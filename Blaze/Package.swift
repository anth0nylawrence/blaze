// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Blaze",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Blaze", targets: ["Blaze"])
    ],
    dependencies: [
        // LanceDB Swift bindings (if available) - fallback to SQLite
        // .package(url: "https://github.com/lancedb/lancedb-swift.git", from: "0.1.0"),

        // SQLite wrapper for fallback/hybrid storage
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),

        // Async algorithms for streaming
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),

        // Collections for ordered dictionaries, deques
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),

        // SwiftUIX - Fill gaps with AppKit-like functionality
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", branch: "master"),

        // Inject - Hot reload support for InjectionIII (DEBUG only)
        .package(url: "https://github.com/krzysztofzablocki/Inject.git", from: "1.5.2"),

        // SwiftTerm - Terminal emulator library for PTY support
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Blaze",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SwiftUIX", package: "SwiftUIX"),
                .product(name: "Inject", package: "Inject"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "BlazeTests",
            dependencies: ["Blaze"],
            path: "Tests"
        )
    ]
)
