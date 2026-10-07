// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoybitPaymentGateway",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "VoybitPaymentGateway", targets: ["VoybitPaymentGateway"]),
    ],
    targets: [
        .target(name: "VoybitPaymentGateway"),
        .testTarget(name: "VoybitPaymentGatewayTests", dependencies: ["VoybitPaymentGateway"]),
    ]
)
