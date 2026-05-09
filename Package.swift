import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MeshChat",
    platforms: [.iOS("16.0")],
    products: [.iOSApplication(name: "MeshChat", targets: ["AppModule"], displayVersion: "1.0", bundleVersion: "1", appIcon: .placeholder(icon: .chat), supportedDeviceFamilies: [.iphone], supportedInterfaceOrientations: [.portrait], capabilities: [.bluetoothAlways(purposeString: "Связь без интернета"), .localNetwork(purposeString: "Связь в Wi-Fi")])],
    targets: [.executableTarget(name: "AppModule", path: "Sources")]
)
