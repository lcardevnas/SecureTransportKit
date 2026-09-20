// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SecureTransportKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SecureStorage", targets: ["SecureStorage"]),
        .library(name: "SecureSession", targets: ["SecureSession"]),
        .library(name: "HTTPTransport", targets: ["HTTPTransport"]),
        .library(name: "HTTPFileTransfer", targets: ["HTTPFileTransfer"]),
        .library(name: "AuthenticatedHTTP", targets: ["AuthenticatedHTTP"]),
    ],
    targets: [
        .target(name: "SecureStorage"),
        .target(name: "SecureSession", dependencies: ["SecureStorage"]),
        .target(name: "HTTPTransport"),
        .target(name: "HTTPFileTransfer", dependencies: ["HTTPTransport"]),
        .target(
            name: "AuthenticatedHTTP",
            dependencies: ["SecureSession", "HTTPTransport"]
        ),
        .testTarget(name: "SecureStorageTests", dependencies: ["SecureStorage"]),
        .testTarget(name: "SecureSessionTests", dependencies: ["SecureSession", "SecureStorage"]),
        .testTarget(name: "HTTPTransportTests", dependencies: ["HTTPTransport"]),
        .testTarget(
            name: "HTTPFileTransferTests",
            dependencies: ["HTTPFileTransfer", "HTTPTransport"]
        ),
        .testTarget(
            name: "AuthenticatedHTTPTests",
            dependencies: ["AuthenticatedHTTP", "SecureSession", "SecureStorage", "HTTPTransport"]
        ),
    ]
)
