import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

struct IconCandidate: Identifiable {
    let url: URL
    let directory: Bool
    let rule: IconRule
    var id: String { url.path }
}

enum IconPainter {
    static func image(_ rule: IconRule, directory: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        image.lockFocus()
        defer { image.unlockFocus() }
        let hex = rule.color.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt32(hex, radix: 16) ?? 0x3178C6
        let color = NSColor(calibratedRed: CGFloat((v >> 16) & 255) / 255,
                            green: CGFloat((v >> 8) & 255) / 255,
                            blue: CGFloat(v & 255) / 255, alpha: 1)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 512, height: 512).fill()
        if directory {
            color.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: NSRect(x: 55, y: 334, width: 215, height: 100), xRadius: 24, yRadius: 24).fill()
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 43, y: 78, width: 426, height: 310), xRadius: 46, yRadius: 46).fill()
        } else {
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 91, y: 40, width: 330, height: 428), xRadius: 40, yRadius: 40).fill()
            NSColor.white.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: NSRect(x: 125, y: 94, width: 260, height: 10), xRadius: 5, yRadius: 5).fill()
        }
        let font: CGFloat = rule.glyph.count <= 3 ? 125 : rule.glyph.count <= 4 ? 98 : 72
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: font, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: p
        ]
        (rule.glyph as NSString).draw(in: NSRect(x: 65, y: 174, width: 382, height: 160), withAttributes: attrs)
        return image
    }
}

@MainActor
final class IconManager: ObservableObject {
    @Published var themes: [IconTheme] = IconTheme.builtins
    @Published var selected = 0
    @Published var root: URL?
    @Published var matches: [IconCandidate] = []
    @Published var status = "选择项目文件夹，预览文件图标主题。"
    @Published var busy = false
    @Published var autoSync = false
    @Published var managedCount = 0
    @Published var scannedCount = 0
    private let maxScanned = 40000
    private let maxMatches = 5000
    private var lastSync = Date.distantPast

    var theme: IconTheme { themes[selected] }

    private var historyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FinderIconTheme", isDirectory: true)
            .appendingPathComponent("applied-icons.json")
    }
    private func history() -> [String: String] {
        guard let data = try? Data(contentsOf: historyURL),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }
    private func save(_ history: [String: String]) {
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(history).write(to: historyURL, options: [.atomic])
        } catch { status = "保存操作记录失败：" + error.localizedDescription }
    }
    private func managed(in folder: URL) -> Int {
        history().keys.filter { $0.hasPrefix(folder.path + "/") }.count
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "使用这个文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url.standardizedFileURL
        scan()
    }
    func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let theme = try JSONDecoder().decode(IconTheme.self, from: Data(contentsOf: url))
            guard !theme.rules.isEmpty else { status = "主题规则不能为空"; return }
            themes.append(theme)
            selected = themes.count - 1
            scan()
        } catch { status = "导入 JSON 失败：" + error.localizedDescription }
    }
    func chooseTheme(_ index: Int) {
        selected = index
        scan()
    }
    func scan() {
        guard let root else { return }
        busy = true
        defer { busy = false }
        matches.removeAll()
        scannedCount = 0
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
            options: [.skipsPackageDescendants]
        ) else { status = "无法读取目录"; return }
        while let url = enumerator.nextObject() as? URL {
            scannedCount += 1
            if scannedCount >= maxScanned || matches.count >= maxMatches { break }
            let flags = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
            if flags?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            let directory = flags?.isDirectory == true
            if directory && IconTheme.ignoredFolders.contains(url.lastPathComponent.lowercased()) {
                enumerator.skipDescendants()
                continue
            }
            if flags?.isPackage == true { enumerator.skipDescendants() }
            if let rule = theme.rule(for: url, isFolder: directory) {
                matches.append(IconCandidate(url: url, directory: directory, rule: rule))
            }
        }
        managedCount = managed(in: root)
        status = "扫描 \(scannedCount) 项，匹配 \(matches.count) 个图标"
    }
    func apply(onlyNew: Bool = false) {
        guard let root else { return }
        if onlyNew { scan() }
        busy = true
        defer { busy = false }
        var old = history()
        var changed = 0
        var failed = 0
        for item in matches {
            let path = item.url.path
            let fingerprint = [theme.name, item.rule.kind.rawValue, item.rule.match,
                               item.rule.glyph, item.rule.color].joined(separator: "|")
            if onlyNew && old[path] == fingerprint { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if NSWorkspace.shared.setIcon(IconPainter.image(item.rule, directory: item.directory), forFile: path, options: []) {
                old[path] = fingerprint
                changed += 1
            } else { failed += 1 }
        }
        save(old)
        managedCount = managed(in: root)
        status = "成功应用 \(changed) 个，失败 \(failed) 个"
    }
    func restore() {
        guard let root else { return }
        autoSync = false
        busy = true
        defer { busy = false }
        var old = history()
        var changed = 0
        var failed = 0
        for path in old.keys.sorted() where path.hasPrefix(root.path + "/") {
            if !FileManager.default.fileExists(atPath: path) {
                old.removeValue(forKey: path)
                continue
            }
            if NSWorkspace.shared.setIcon(nil, forFile: path, options: []) {
                old.removeValue(forKey: path)
                changed += 1
            } else { failed += 1 }
        }
        save(old)
        managedCount = managed(in: root)
        status = "恢复 \(changed) 个默认图标，失败 \(failed) 个"
    }
    func syncTick() {
        guard autoSync, root != nil, Date().timeIntervalSince(lastSync) >= 55 else { return }
        lastSync = Date()
        apply(onlyNew: true)
    }
}

struct MainView: View {
    @ObservedObject var model: IconManager
    @State private var confirmApply = false
    @State private var confirmRestore = false
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Finder Icon Theme", systemImage: "square.stack.3d.up.fill").font(.headline).padding(.top, 22)
                Text("文件图标主题").font(.caption).foregroundColor(.secondary)
                Divider()
                ForEach(Array(model.themes.enumerated()), id: \.offset) { index, theme in
                    Button {
                        model.chooseTheme(index)
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(index == model.selected ? .accentColor : .secondary)
                            Text(theme.name)
                            Spacer()
                            if index == model.selected { Image(systemName: "checkmark") }
                        }
                        .padding(10)
                        .background(index == model.selected ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Button("导入 JSON 主题", action: model.importTheme)
                Text("macOS 13+ · Finder").font(.caption2).foregroundColor(.secondary).padding(.bottom, 12)
            }
            .padding(.horizontal, 18)
            .frame(width: 220, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Text("为 Finder 应用文件图标主题").font(.system(size: 24, weight: .bold))
                Text("按文件名、扩展名和文件夹名匹配图标。先预览，再应用。")
                    .font(.subheadline).foregroundColor(.secondary)
                HStack {
                    Image(systemName: "folder.fill").foregroundColor(.accentColor).font(.title2)
                    VStack(alignment: .leading) {
                        Text(model.root?.lastPathComponent ?? "未选择项目文件夹").font(.headline)
                        Text(model.root?.path ?? "请先选择一个文件夹")
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button("选择文件夹", action: model.chooseFolder)
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                HStack {
                    Text("已扫描 \(model.scannedCount) 项")
                    Spacer()
                    Text("匹配 \(model.matches.count) 项")
                    Spacer()
                    Text("已应用 \(model.managedCount) 项")
                    Button("重新扫描", action: model.scan).disabled(model.root == nil)
                }.font(.caption)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                        ForEach(Array(model.matches.prefix(120))) { item in
                            VStack(spacing: 6) {
                                Image(nsImage: IconPainter.image(item.rule, directory: item.directory))
                                    .resizable().scaledToFit().frame(width: 54, height: 54)
                                Text(item.url.lastPathComponent)
                                    .font(.caption2).lineLimit(1).truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity).padding(12)
                            .background(Color(nsColor: .controlBackgroundColor)).cornerRadius(9)
                        }
                    }.padding(12)
                    if model.matches.isEmpty { Text("选择文件夹以预览主题").foregroundColor(.secondary).padding(48) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Toggle("自动同步（每 60 秒）", isOn: $model.autoSync).disabled(model.root == nil)
                    Spacer()
                    Button("恢复默认图标") { confirmRestore = true }.disabled(model.managedCount == 0)
                    Button("应用主题") { confirmApply = true }
                        .buttonStyle(.borderedProminent).disabled(model.matches.isEmpty)
                }
                Text(model.status).font(.caption).foregroundColor(.secondary)
            }
            .padding(24)
        }
        .frame(minWidth: 830, minHeight: 580)
        .onReceive(ticker) { _ in model.syncTick() }
        .confirmationDialog("确认批量应用？", isPresented: $confirmApply) {
            Button("应用到 \(model.matches.count) 个文件/文件夹") { model.apply() }
        } message: { Text("将覆盖目标原有的自定义图标。请先在测试文件夹尝试。") }
        .confirmationDialog("恢复默认图标？", isPresented: $confirmRestore) {
            Button("恢复 \(model.managedCount) 项", role: .destructive) { model.restore() }
        } message: { Text("恢复为 Finder 默认图标，无法找回此前已有的自定义图标。") }
    }
}

@main
struct FinderIconThemeApp: App {
    @StateObject private var model = IconManager()
    var body: some Scene {
        WindowGroup("Finder Icon Theme") { MainView(model: model) }
    }
}
