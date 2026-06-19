// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PaperTodoMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PaperTodoMac", targets: ["PaperTodoMac"])
    ],
    targets: [
        .target(
            name: "PaperTodoCore",
            path: "Sources/PaperTodoCore"
        ),
        .executableTarget(
            name: "PaperTodoMac",
            dependencies: ["PaperTodoCore"],
            path: "Sources/PaperTodoMac",
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "PaperTodoCoreTests",
            dependencies: ["PaperTodoCore", "PaperTodoMac"],
            path: "Tests/PaperTodoCoreTests"
        )
    ]
)
