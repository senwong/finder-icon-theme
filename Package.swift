// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"FinderIconTheme",platforms:[.macOS(.v13)],products:[.executable(name:"FinderIconTheme",targets:["FinderIconTheme"])],targets:[.executableTarget(name:"FinderIconTheme",path:"Sources/FinderIconTheme")])
