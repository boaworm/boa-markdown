// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "BoaRender",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "BoaRender", targets: ["BoaRender"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/cmark-gfm"),
    ],
    targets: [
        .target(
            name: "BoaRender",
            dependencies: [
                .product(name: "cmark-gfm", package: "cmark-gfm"),
                .product(name: "cmark-gfm-extensions", package: "cmark-gfm"),
            ]
        ),
        .testTarget(name: "BoaRenderTests", dependencies: ["BoaRender"]),
    ]
)
