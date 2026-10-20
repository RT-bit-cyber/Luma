// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Luma",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Luma", targets: ["Luma"])],
    targets: [
        .target(name: "AmbientHardware", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        .target(name: "LumaCore"),
        .executableTarget(name: "Luma", dependencies: ["AmbientHardware", "LumaCore"], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]),
        .testTarget(name: "LumaCoreTests", dependencies: ["LumaCore"])
    ]
)
