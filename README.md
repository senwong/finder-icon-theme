# Finder Icon Theme

A native macOS **Finder file icon theme manager** (macOS 13+, SwiftUI + AppKit).

## Download

**[GitHub Releases](https://github.com/senwong/finder-icon-theme/releases)**

Choose the DMG for your Mac, open it, then drag FinderIconTheme.app into Applications:

- **Intel (x86_64; macOS 13+)**: `FinderIconTheme-v0.1.1-macOS-x86_64.dmg`
- **Apple Silicon (arm64; macOS 13+)**: `FinderIconTheme-v0.1.1-macOS-arm64.dmg`

Find your chip with `uname -m`. A DMG built for Apple Silicon alone cannot run on Intel. Releases are built with separate GitHub Actions runners and verify the *actual Mach-O binary* has the expected architecture and minimum macOS 13.0 deployment target. Note: CI builds on macOS 15; it does not yet execute the app on a macOS 13 machine.

> The initial release is ad-hoc signed, **not Apple-notarized**. macOS Gatekeeper may warn on first launch. Only allow it after checking the repository and release yourself. To avoid Gatekeeper warnings entirely, Developer ID signing + Apple notarization are required.

## Features

- Aurora and Pastel built-in themes
- File extensions (.ts, .tsx, .md...), named files (package.json, Dockerfile, README*), and folders (src, docs, components...)
- Import a custom JSON theme (see examples/theme.json)
- Preview matched files, then apply Finder custom icons to the selected project directory
- Opt-in automatic synchronization every 60 seconds while app is open
- Restore macOS default icons on files previously managed by the app
- Exclude .git, node_modules, dist and other generated folders; scan limits (40,000 entries, 5,000 matches)

**Limitations:** Finder does not expose a public global icon-theme API like VS Code. This app applies *per-file* and *per-folder* custom icons using NSWorkspace.setIcon. It does not change every .ts/.md file system-wide. Restore cannot recover preexisting custom icons that were overwritten; it returns to the system default. Files' contents are unchanged.

## Development

Install Xcode Command Line Tools on macOS, then:

~~~bash
./tests/test-matcher.sh
./build-macos.sh
./package-dmg.sh
~~~

Local outputs: `dist/FinderIconTheme.app` and `dist/FinderIconTheme-v0.1.1-macOS-$(uname -m).dmg` (replace `$(uname -m)` with your architecture).

## Publish

The GitHub Actions **Release DMG** workflow builds both Intel (`macos-15-intel`) and Apple Silicon (`macos-15`) variants, verifies their Mach-O deployment targets, tests theme matching and uploads both architecture-specific DMGs + SHA-256 files. Pushing the compatibility fix creates v0.1.1. For subsequent versions, use Actions > Release DMG > Run workflow and enter a new tag such as v0.2.0.

## Security

Test the app in a disposable directory first. Applying Finder icons changes filesystem metadata, which can be synchronized/backed up. Avoid system folders and files with existing custom icons. Scanning is bounded and excludes symbolic links.
