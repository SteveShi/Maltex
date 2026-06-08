// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Maltex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Maltex", targets: ["Maltex"])
    ],
    dependencies: [
        .package(url: "https://github.com/baptistecdr/Aria2Kit", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Maltex",
            dependencies: [
                "Aria2Kit"
            ],
            path: "Maltex",
            resources: [
                .process("Assets.xcassets"),
                .process("Localizable.xcstrings"),
                .process("InfoPlist.xcstrings")
            ]
        )
    ]
)