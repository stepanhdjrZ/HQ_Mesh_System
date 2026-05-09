// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Messenger",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Messenger", targets: ["Messenger"])],
    targets: [
        .target(
            name: "Messenger",
            path: ".",
            sources: ["ContentView.swift"]
        )
    ]
)
