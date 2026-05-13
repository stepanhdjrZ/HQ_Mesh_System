// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HQGlobalMesh",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "HQGlobalMesh", targets: ["HQGlobalMesh"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToDateWithMiniVersion(from: "10.0.0"))
    ],
    targets: [
        .target(
            name: "HQGlobalMesh",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: ".",
            exclude: ["Package.swift", "GoogleService-Info.plist", ".github"]
        )
    ]
)
