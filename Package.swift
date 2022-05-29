// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pdfrecord",
    platforms: [.iOS(.v12), .macOS(.v12), .macCatalyst(.v14)],
    products: [
        .library(
            name: "pdfrecord",
            targets: ["pdfrecord"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/awxkee/pdfwriter.git", branch: "master")
    ],
    targets: [
        .target(
            name: "pdfrecord",
            dependencies: [.product(name: "pdfwriter", package: "pdfwriter")],
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("z")]),
        .testTarget(
            name: "xpdfTests",
            dependencies: ["pdfrecord"]),
    ]
)
