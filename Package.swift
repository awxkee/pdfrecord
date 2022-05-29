// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xpdf",
    platforms: [.iOS(.v12), .macOS(.v12), .macCatalyst(.v14)],
    products: [
        .library(
            name: "xpdf",
            targets: ["xpdf"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/awxkee/pdfwriter.git", branch: "master")
    ],
    targets: [
        .target(
            name: "xpdf",
            dependencies: [.product(name: "pdfwriter", package: "pdfwriter")],
            publicHeadersPath: "include"),
        .testTarget(
            name: "xpdfTests",
            dependencies: ["xpdf"]),
    ]
)
