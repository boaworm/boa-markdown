import PackageDescription

let package = Package(
    name: "BoaMarkdown",
    platforms: [.macOS(.v12)],
    targets: [
        .target(
            name: "Markdown",
            path: "Sources/Markdown",
            sources: [
                "MarkdownApp.swift",
                "Common/",
                "LocalSchemeHandler.swift",
                "NotificationNames.swift",
                "ResourceLoader.swift",
                "WindowSizePersistence.swift",
            ]
        ),
        .target(
            name: "MarkdownPreview",
            path: "Sources/MarkdownPreview"
        ),
    ]
)
