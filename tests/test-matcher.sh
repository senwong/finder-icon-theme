#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/main.swift" <<'SWIFT'
import Foundation
let theme = IconTheme.builtins[0]
func check(_ name: String, folder: Bool = false, kind: IconMatchKind) {
    precondition(theme.rule(for: URL(fileURLWithPath: "/tmp/test/" + name), isFolder: folder)?.kind == kind, "Missing: \(name)")
}
check("package.json", kind: .filename)
check("README.md", kind: .filename)
check("index.ts", kind: .ext)
check("test.tsx", kind: .ext)
check("src", folder: true, kind: .folder)
check(".env.local", kind: .filename)
precondition(theme.rule(for: URL(fileURLWithPath: "/tmp/test/random.xyz"), isFolder: false) == nil)
print("PASS 7 theme rules")
SWIFT
swiftc Sources/FinderIconTheme/Theme.swift "$TMP/main.swift" -o "$TMP/check"
"$TMP/check"
