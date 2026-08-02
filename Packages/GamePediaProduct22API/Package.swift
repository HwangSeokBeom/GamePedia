// swift-tools-version:6.1
import PackageDescription

// MARK: - GamePediaProduct22API
//
// The Product 2.2 server contract, isolated in a local package so the
// generated transport types can never leak into the app by accident.
//
// Nothing in this package is written by hand except the client factory:
// `Sources/GamePediaProduct22API/openapi.json` is a byte-exact copy of the
// server's contract document and the Swift types are produced from it by the
// swift-openapi-generator build plugin at compile time. See PROVENANCE.md for
// the server HEAD, source path and SHA-256 this copy was taken from.
//
// The three swift-openapi packages are pinned with `exact:` on purpose: a
// contract client that silently changes its decoding behaviour on a patch
// bump is not a contract client.

let package = Package(
    name: "GamePediaProduct22API",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "GamePediaProduct22API", targets: ["GamePediaProduct22API"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.11.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.12.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.3.1"),
        // The generated Client.swift imports HTTPTypes directly, so the target
        // genuinely depends on it. Declaring it is not optional: SwiftPM's
        // static build happens to resolve it transitively, but Xcode links this
        // product as a dynamic framework and fails with undefined HTTPTypes
        // symbols unless it is an explicit dependency. Pinned to the version
        // the swift-openapi packages already resolve to, so Package.resolved
        // does not move.
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.6.0")
    ],
    targets: [
        .target(
            name: "GamePediaProduct22API",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "GamePediaProduct22APITests",
            dependencies: ["GamePediaProduct22API"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
