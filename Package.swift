// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

//var linkerSettings: [LinkerSetting] = []
//#if os(macOS)
//linkerSettings.append(.unsafeFlags([
//    "-Xlinker", "-undefined",
//    "-Xlinker", "dynamic_lookup",
//]))
//#endif

var libraryType: Product.Library.LibraryType
#if os(Windows)
libraryType = .static
#else
libraryType = .dynamic
#endif

// Products define the executables and libraries a package produces, and make them visible to other packages.
var products: [Product] = [
    .library(
        name: "SwiftGodot",
        type: libraryType,
        targets: ["SwiftGodot"]),
    .library(
        name: "SwiftGodotStatic",
        targets: ["SwiftGodot"]),
    .library(
        name: "ExtensionApi",
        targets: [
            "ExtensionApi",
            "ExtensionApiJson"
        ]),
    .plugin(name: "CodeGeneratorPlugin", targets: ["CodeGeneratorPlugin"]),
    .plugin(name: "EntryPointGeneratorPlugin", targets: ["EntryPointGeneratorPlugin"])
]

// Macros aren't supported on Windows before 5.9.1 and this sample uses them
#if !(os(Windows) && swift(<5.9.1))
products.append(
    .library(
        name: "SimpleExtension",
        type: libraryType,
        targets: ["SimpleExtension"]))
#endif

// libgodot is only available for macOS and testability runtime depends on it
#if os(macOS)
products.append(
    .library(
        name: "SwiftGodotTestability",
        targets: ["SwiftGodotTestability"]))
#endif

var targets: [Target] = [
    .executableTarget(
        name: "EntryPointGenerator",
        dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]
    ),
    // This contains GDExtension's JSON API data models
    .target(
        name: "ExtensionApi",
        exclude: ["ExtensionApiJson.swift", "extension_api.json"]),
    // This contains a resource bundle with extension_api.json
    .target(
        name: "ExtensionApiJson",
        path: "Sources/ExtensionApi",
        exclude: ["ApiJsonModel.swift", "ApiJsonModel+Extra.swift"],
        sources: ["ExtensionApiJson.swift"],
        resources: [.process("extension_api.json")]),
    
    // The generator takes Godot's JSON-based API description as input and
    // produces Swift API bindings that can be used to call into Godot.
    .executableTarget(
        name: "Generator",
        dependencies: [
            "ExtensionApi",
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
        ],
        path: "Generator",
        exclude: ["README.md"],
        swiftSettings: [
            // Uncomment for using legacy array-based marshalling
            //.define("LEGACY_MARSHALING")
        ]
    ),
    
    // This is a build-time plugin that invokes the generator and produces
    // the bindings that are compiled into SwiftGodot
        .plugin(
            name: "CodeGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["Generator"]
        ),
    
        .plugin(
            name: "EntryPointGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["EntryPointGenerator"]
        ),
    
    // This allows the Swift code to call into the Godot bridge API (GDExtension)
    .target(
        name: "GDExtension"),
]

var swiftGodotPlugins: [Target.PluginUsage] = ["CodeGeneratorPlugin"]

// Macros aren't supported on Windows before 5.9.1
#if !(os(Windows) && swift(<5.9.1))
targets.append(contentsOf: [
    // These are macros that can be used by third parties to simplify their
    // SwiftGodot development experience, these are used at compile time by
    // third party projects
    .macro(name: "SwiftGodotMacroLibrary",
           dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
           ]),
    // This contains sample code showing how to use the SwiftGodot API
    .target(
        name: "SimpleExtension",
        dependencies: ["SwiftGodot"],
        exclude: ["SwiftSprite.gdextension", "README.md"]),
        //linkerSettings: linkerSettings),
])
swiftGodotPlugins.append("SwiftGodotMacroLibrary")
#endif

// Macro tests don't work on Windows yet
#if !os(Windows)
// Idea: -mark_dead_strippable_dylib
targets.append(
    .testTarget(name: "SwiftGodotMacrosTests",
            dependencies: [
                "SwiftGodotMacroLibrary",
                "SwiftGodot",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]))
#endif

// libgodot is only available for macOS
#if os(macOS)

/// You might want to build your own libgodot, so you can step into it in the debugger when fixing failing tests. Here's how:
///
/// 1. Check out the appropriate branch of https://github.com/migueldeicaza/libgodot
/// 2. Build with `scons platform=macos target=template_debug dev_build=yes library_type=shared_library`. The `target=template_debug` is important, because `target=editor` will get you a `TOOLS_ENABLED` build that breaks some test cases.
/// 3. Use `scripts/make-libgodot.framework` to build an `xcframework` and put it at the root of your SwiftGodot work tree.
/// 4. Change `#if true` to `#if false` below.
///
#if true
let libgodot_tests = Target.binaryTarget(
    name: "libgodot_tests",
    url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/4.3.5/libgodot.xcframework.zip",
    checksum: "865ea17ad3e20caab05b3beda35061f57143c4acf0e4ad2684ddafdcc6c4f199"
)
#else
let libgodot_tests = Target .binaryTarget(
    name: "libgodot_tests",
    path: "libgodot.xcframework"
)
#endif

targets.append(contentsOf: [
    // Godot runtime as a library

    libgodot_tests,

    // Base functionality for Godot runtime dependant tests
    .target(
        name: "SwiftGodotTestability",
        dependencies: [            
            "SwiftGodot",
            "libgodot_tests",
            "GDExtension"
        ]),
    
    // General purpose runtime dependant tests
    .testTarget(
        name: "SwiftGodotTests",
        dependencies: [
            "SwiftGodotTestability",
        ]
    ),
    
    // Runtime dependant tests based on the engine tests from Godot's repository
    .testTarget(
        name: "SwiftGodotEngineTests",
        dependencies: [
            "SwiftGodotTestability",
        ]
    ),
])
#endif

targets.append(contentsOf: [
    // This is the binding itself, it is made up of our generated code for the
    // Godot API, supporting infrastructure and extensions to the API to provide
    // a better Swift experience
    .target(
        name: "SwiftGodot",
        dependencies: ["GDExtension"],
        //linkerSettings: linkerSettings,
        swiftSettings: [
            .define("CUSTOM_BUILTIN_IMPLEMENTATIONS")
        ],
        plugins: swiftGodotPlugins
    ),
    
    // General purpose cross-platform tests
    .testTarget(
        name: "SwiftGodotUniversalTests",
        dependencies: [
            "SwiftGodot",
            "ExtensionApi",
            "ExtensionApiJson",
        ]
    ),
])

let package = Package(
    name: "SwiftGodot",
    platforms: [
        .macOS(.v13),
        .iOS (.v15)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "510.0.1"),
    ],
    targets: targets
)
