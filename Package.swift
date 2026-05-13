// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HQGlobalMesh",
    platforms: [
        .iOS(.v15) // Поддержка твоего iPhone 8 и выше
    ],
    products: [
        .library(name: "HQGlobalMesh", targets: ["HQGlobalMesh"])
    ],
    dependencies: [
        // Тот самый Firebase, который валит билды
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
            path: "." // Гитхаб будет искать код во всех папках
        )
    ]
)
