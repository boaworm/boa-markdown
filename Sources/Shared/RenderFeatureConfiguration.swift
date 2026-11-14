/// The theme-only fast path is valid only when all parser/style inputs agree.
struct RenderFeatureConfiguration: Equatable {
    var fontSize: Double
    var katex: Bool
    var emoji: Bool
    var codeTheme: String
}
