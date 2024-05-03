// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ccswift",
    platforms: [
        .iOS(.v15) // Set the minimum deployment target to iOS 15.0
    ],
    products: [
        .library(
            name: "ccswift",
            targets: ["ccswift"]),
    ],
    dependencies: [ // Add your package dependencies here
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
    ],
    targets: [
        .target(
            name: "ccswift",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"), // Explicitly declare SocketIO dependency
            ]),
        .testTarget(
            name: "ccswiftTests",
            dependencies: ["ccswift"]),
    ]
)
