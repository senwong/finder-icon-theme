import Foundation

enum IconMatchKind: String, Codable {
    case filename
    case ext = "extension"
    case folder
}
struct IconRule: Codable, Hashable {
    var kind: IconMatchKind
    var match: String
    var glyph: String
    var color: String
}
struct IconTheme: Codable, Identifiable {
    var name: String
    var rules: [IconRule]
    var id: String { name }

    func rule(for url: URL, isFolder: Bool) -> IconRule? {
        let filename = url.lastPathComponent.lowercased()
        let kind: IconMatchKind = isFolder ? .folder : .filename
        if let direct = rules.first(where: { $0.kind == kind && Self.match($0.match.lowercased(), filename) }) { return direct }
        if !isFolder {
            let ext = url.pathExtension.lowercased()
            return rules.first(where: { $0.kind == .ext && $0.match.lowercased().trimmingCharacters(in: CharacterSet(charactersIn:".")) == ext })
        }
        return nil
    }
    private static func match(_ pattern: String, _ text: String) -> Bool {
        if pattern == text || pattern == "*" { return true }
        guard pattern.contains("*") else { return false }
        let regex = "^" + NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*") + "$"
        return text.range(of: regex, options:.regularExpression) != nil
    }
    static let ignoredFolders: Set<String> = [".git","node_modules",".next",".nuxt",".build","dist","build","target","coverage",".venv","venv","vendor","deriveddata"]

    static func builtin(name: String, muted: Bool) -> IconTheme {
        // kind|filename/extension|glyph|bright hex|pastel hex
        let source = """
        filename|package.json|npm|#CB3837|#B66F70
        filename|package-lock.json|LOCK|#CB3837|#B66F70
        filename|pnpm-lock.yaml|pnpm|#E17A37|#BF906D
        filename|Dockerfile|DOCK|#3178C6|#618DB4
        filename|README*|READ|#138B9B|#6A9DA7
        filename|LICENSE*|LIC|#687789|#8996A3
        filename|.gitignore|GIT|#E17A37|#BF906D
        filename|.env*|ENV|#E6AC33|#BA9B5D
        filename|tsconfig*.json|TS|#3178C6|#618DB4
        filename|vite.config.*|VITE|#8365C7|#A38ABF
        filename|next.config.*|NEXT|#687789|#8996A3
        filename|Cargo.toml|RUST|#E17A37|#BF906D
        filename|go.mod|GO|#138B9B|#6A9DA7
        extension|ts|TS|#3178C6|#618DB4
        extension|tsx|TSX|#3178C6|#618DB4
        extension|js|JS|#E6AC33|#BA9B5D
        extension|jsx|JSX|#E6AC33|#BA9B5D
        extension|json|JSON|#E6AC33|#BA9B5D
        extension|md|MD|#138B9B|#6A9DA7
        extension|mdx|MDX|#138B9B|#6A9DA7
        extension|html|HTML|#E17A37|#BF906D
        extension|css|CSS|#8365C7|#A38ABF
        extension|scss|SCSS|#D4568F|#BF85A4
        extension|vue|VUE|#279C79|#67A18D
        extension|svelte|SV|#E17A37|#BF906D
        extension|py|PY|#3178C6|#618DB4
        extension|rs|RS|#E17A37|#BF906D
        extension|go|GO|#138B9B|#6A9DA7
        extension|swift|SW|#E17A37|#BF906D
        extension|sh|SH|#279C79|#67A18D
        extension|zsh|SH|#279C79|#67A18D
        extension|yaml|YAML|#D4568F|#BF85A4
        extension|yml|YML|#D4568F|#BF85A4
        extension|xml|XML|#E17A37|#BF906D
        extension|toml|TOML|#687789|#8996A3
        extension|sql|SQL|#138B9B|#6A9DA7
        extension|php|PHP|#8365C7|#A38ABF
        extension|rb|RB|#D95454|#BF7777
        extension|java|JAVA|#E17A37|#BF906D
        extension|c|C|#3178C6|#618DB4
        extension|cpp|C++|#3178C6|#618DB4
        folder|src|SRC|#3178C6|#618DB4
        folder|components|UI|#8365C7|#A38ABF
        folder|pages|PAGE|#138B9B|#6A9DA7
        folder|app|APP|#3178C6|#618DB4
        folder|public|WEB|#279C79|#67A18D
        folder|assets|ART|#D4568F|#BF85A4
        folder|images|IMG|#D4568F|#BF85A4
        folder|styles|CSS|#8365C7|#A38ABF
        folder|tests|TEST|#279C79|#67A18D
        folder|__tests__|TEST|#279C79|#67A18D
        folder|docs|DOC|#138B9B|#6A9DA7
        folder|.github|GIT|#687789|#8996A3
        folder|scripts|SH|#279C79|#67A18D
        folder|config|CFG|#E6AC33|#BA9B5D
        folder|locales|I18N|#138B9B|#6A9DA7
        """
        let rules = source.split(separator:"\n").compactMap { line -> IconRule? in
            let parts = line.trimmingCharacters(in:.whitespaces).split(separator:"|")
            guard parts.count == 5, let kind = IconMatchKind(rawValue:String(parts[0])) else { return nil }
            return IconRule(kind:kind,match:String(parts[1]),glyph:String(parts[2]),color:String(parts[muted ? 4 : 3]))
        }
        return IconTheme(name:name,rules:rules)
    }
    static let builtins: [IconTheme] = [builtin(name:"Aurora",muted:false),builtin(name:"Pastel",muted:true)]
}
