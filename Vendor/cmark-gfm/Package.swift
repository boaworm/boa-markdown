// swift-tools-version:5.3
// Trimmed from upstream swift-cmark: library targets only (no CLI, no api_test).

import PackageDescription

let package = Package(
    name: "cmark-gfm",
    products: [
        .library(name: "cmark-gfm", targets: ["cmark-gfm"]),
        .library(name: "cmark-gfm-extensions", targets: ["cmark-gfm-extensions"]),
    ],
    targets: [
        .target(name: "cmark-gfm", path: "src", exclude: ["scanners.re"]),
        .target(name: "cmark-gfm-extensions", dependencies: ["cmark-gfm"], path: "extensions", exclude: ["ext_scanners.re"]),
    ]
)
