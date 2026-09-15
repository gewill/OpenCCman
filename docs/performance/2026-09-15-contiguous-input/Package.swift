// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ContiguousInputBenchmark",
    platforms: [.macOS(.v11)],
    dependencies: [.package(url: "https://github.com/gewill/SwiftyOpenCC", revision: "6eded293f5c84c064f332cbc2832391165c82dda")],
    targets: [.executableTarget(name: "ContiguousInputBenchmark", dependencies: [.product(name: "OpenCC", package: "SwiftyOpenCC")])]
)
