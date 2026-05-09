// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Messenger",
    platforms: [
        .iOS(.v17) 
    ],
    products: [
        .executable(
            name: "Messenger",
            targets: ["Messenger"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Messenger",
            path: ".",
            exclude: [".github"],
            sources: ["ContentView.swift"]
        )
    ]
)
