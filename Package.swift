// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
 This source file is part of the Swift.org open source project
 Copyright 2015 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription

let package = Package(
    name: "osx-a11y-tools",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .executable(name: "accercise", targets: ["accercise"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/kylef/Commander.git", from: "0.9.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "accercise", dependencies: ["Commander"]),
    ]
)