//
//  SwiftDocCMultiTargets.swift
//
//
//  Created by Ruiyang Sun on 6/28/24.
//

#if os(Windows)
    import WinSDK
#endif
import Foundation
import PackagePlugin

// MARK: - SwiftDocCMultiTargets

@available(macOS 13.0, *)
@main struct SwiftDocCMultiTargets: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let doccExecutableURL = try context.doccExecutable

        var argumentExtractor = ArgumentExtractor(arguments)
        guard let mainTarget = argumentExtractor.mainTarget() else {
            Diagnostics.error("Please specify the main target with --main-target.")
            return
        }
        let targets = argumentExtractor.targets()
        let allTargets = [mainTarget] + targets
        guard let outputDirectory = argumentExtractor.outputDirectory() else {
            Diagnostics.error("Please specify the output directory with --output-directory.")
            return
        }

        let outputURL = URL(filePath: outputDirectory)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path()) {
            try fileManager.removeItem(at: outputURL)
        }
        let cacheDirectory = outputURL.appending(path: "cache")
        if fileManager.fileExists(atPath: cacheDirectory.path()) {
            try fileManager.removeItem(at: cacheDirectory)
        }
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)

        for target in allTargets {
            if try !generateDocumentation(for: target, outputDirectory: outputDirectory, context: context) {
                return
            }
        }

        try fileManager.createDirectory(at: outputURL.appending(path: "data"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "data").appending(path: "documentation"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "documentation"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "downloads"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "images"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "index"), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: outputURL.appending(path: "videos"), withIntermediateDirectories: true, attributes: nil)

        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "css"),
            to: outputURL.appending(path: "css")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "img"),
            to: outputURL.appending(path: "img")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "js"),
            to: outputURL.appending(path: "js")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "developer-og-twitter.jpg"),
            to: outputURL.appending(path: "developer-og-twitter.jpg")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "developer-og.jpg"),
            to: outputURL.appending(path: "developer-og.jpg")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "favicon.ico"),
            to: outputURL.appending(path: "favicon.ico")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "favicon.svg"),
            to: outputURL.appending(path: "favicon.svg")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "index.html"),
            to: outputURL.appending(path: "index.html")
        )
        try fileManager.copyItem(
            at: cacheDirectory.appending(path: mainTarget).appending(path: "metadata.json"),
            to: outputURL.appending(path: "metadata.json")
        )

        for target in allTargets {
            let targetURL = cacheDirectory.appending(path: target)
            if fileManager.fileExists(atPath: targetURL.appending(path: "data").appending(path: "documentation").appending(path: target.lowercased()).path()) {
                try? fileManager.copyItem(
                    at: targetURL.appending(path: "data").appending(path: "documentation").appending(path: target.lowercased()),
                    to: outputURL.appending(path: "data").appending(path: "documentation").appending(path: target.lowercased())
                )
            }
            try? fileManager.copyItem(
                at: targetURL.appending(path: "data").appending(path: "documentation").appending(path: "\(target.lowercased()).json"),
                to: outputURL.appending(path: "data").appending(path: "documentation").appending(path: "\(target.lowercased()).json")
            )
            try? fileManager.copyItem(
                at: targetURL.appending(path: "documentation").appending(path: target.lowercased()),
                to: outputURL.appending(path: "documentation").appending(path: target.lowercased())
            )
            try? fileManager.copyItem(
                at: targetURL.appending(path: "downloads").appending(path: target.lowercased()),
                to: outputURL.appending(path: "downloads").appending(path: target.lowercased())
            )
            try? fileManager.copyItem(
                at: targetURL.appending(path: "images").appending(path: target.lowercased()),
                to: outputURL.appending(path: "images").appending(path: target.lowercased())
            )
            try? fileManager.copyItem(
                at: targetURL.appending(path: "videos").appending(path: target.lowercased()),
                to: outputURL.appending(path: "videos").appending(path: target.lowercased())
            )
        }

        var index: [String: Any] = [
            "includedArchiveIdentifiers": allTargets,
            "interfaceLanguages": [:],
        ]

        let mainIndex = try readJsonFile(url: cacheDirectory.appending(path: mainTarget).appending(path: "index").appending(path: "index.json"))
        index["schemaVersion"] = mainIndex["schemaVersion"]

        for target in targets {
            let targetIndex = try readJsonFile(url: cacheDirectory.appending(path: target).appending(path: "index").appending(path: "index.json"))
            let targetInterfaceLanguages = targetIndex["interfaceLanguages"] as! [String: [Any]]
            for var (language, value) in targetInterfaceLanguages {
                for var (i, subValue) in value.enumerated() {
                    if
                        var subValue = subValue as? [String: Any],
                        var children = subValue["children"] as? [Any]
                    {
                        children.insert(
                            [
                                "title": "Back to \(mainTarget)",
                                "type": "module",
                                "path": "../\(mainTarget.lowercased())",
                            ],
                            at: 0
                        )
                        subValue["children"] = children
                        value[i] = subValue
                    }
                }
                
                var interfaceLanguages = index["interfaceLanguages"] as! [String: Any]
                if interfaceLanguages[language] == nil {
                    interfaceLanguages[language] = value
                } else if var mainValue = interfaceLanguages[language] as? [Any] {
                    mainValue.append(contentsOf: value)
                    interfaceLanguages[language] = mainValue
                }
                index["interfaceLanguages"] = interfaceLanguages
            }
        }

        var mainInterfaceLanguages = (mainIndex["interfaceLanguages"] as! [String: [[String: Any]]])["swift"]?[0] ?? [:]
        mainInterfaceLanguages["children"] = targets.map { target in
            [
                "title": target,
                "type": "module",
                "path": "../\(target.lowercased())",
            ]
        }

        var interfaceLanguages = (index["interfaceLanguages"] as! [String: [[String: Any]]])
        var interfaceLanguagesSwift = interfaceLanguages["swift"] ?? []
        interfaceLanguagesSwift.append(mainInterfaceLanguages)
        interfaceLanguages["swift"] = interfaceLanguagesSwift
        index["interfaceLanguages"] = interfaceLanguages

        let jsonData = try JSONSerialization.data(withJSONObject: index, options: .prettyPrinted)
        try jsonData.write(to: outputURL.appending(path: "index").appending(path: "index.json"))

        try fileManager.removeItem(at: cacheDirectory)
    }

    func readJsonFile(url: URL) throws -> [String: Any] {
        let data = try! Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    }

    func generateDocumentation(for target: String, outputDirectory: String, context: PluginContext) throws -> Bool {
        print("Generating documentation for '\(target)'...")

        let arguments = [
            "--disable-indexing",
            "--target",
            target,
            "--output-path",
            URL(filePath: outputDirectory).appending(path: "cache").appending(path: target).path(),
            "--transform-for-static-hosting",
        ]

        // We'll be creating commands that invoke `docc`, so start by locating it.
        let doccExecutableURL = try context.doccExecutable

        var argumentExtractor = ArgumentExtractor(arguments)
        let specifiedTargets = try argumentExtractor.extractSpecifiedTargets(in: context.package)

        let swiftSourceModuleTargets: [SwiftSourceModuleTarget] =
            if specifiedTargets.isEmpty {
                context.package.allDocumentableTargets
            } else {
                specifiedTargets
            }

        guard !swiftSourceModuleTargets.isEmpty else {
            throw ArgumentParsingError.packageDoesNotContainSwiftSourceModuleTargets
        }
        let verbose = false

        let parsedArguments = ParsedArguments(argumentExtractor.remainingArguments)

        #if swift(>=5.7)
            let snippetExtractTool = try context.tool(named: "snippet-extract")
            let snippetExtractor = SnippetExtractor(
                snippetTool: URL(fileURLWithPath: snippetExtractTool.path.string, isDirectory: false),
                workingDirectory: URL(fileURLWithPath: context.pluginWorkDirectory.string, isDirectory: true)
            )
        #else
            let snippetExtractor: SnippetExtractor? = nil
        #endif

        // Iterate over the Swift source module targets we were given.
        for (index, target) in swiftSourceModuleTargets.enumerated() {
            if index != 0 {
                // Emit a line break if this is not the first target being built.
                print()
            }

            let symbolGraphs = try packageManager.doccSymbolGraphs(
                for: target,
                context: context,
                verbose: verbose,
                snippetExtractor: snippetExtractor,
                customSymbolGraphOptions: parsedArguments.symbolGraphArguments
            )

            if try FileManager.default.contentsOfDirectory(atPath: symbolGraphs.targetSymbolGraphsDirectory.path).isEmpty {
                // This target did not produce any symbol graphs. Let's check if it has a
                // DocC catalog.

                guard target.doccCatalogPath != nil else {
                    let message = """
                    '\(target.name)' does not contain any documentable symbols or a \
                    DocC catalog and will not produce documentation
                    """

                    if swiftSourceModuleTargets.count > 1 {
                        // We're building multiple targets, just throw a warning for this
                        // one target that does not produce documentation.
                        Diagnostics.warning(message)
                        continue
                    } else {
                        // This is the only target being built so throw an error
                        Diagnostics.error(message)
                        return false
                    }
                }
            }

            // Construct the output path for the generated DocC archive
            let doccArchiveOutputPath = target.doccArchiveOutputPath(in: context)

            // Use the parsed arguments gathered earlier to generate the necessary
            // arguments to pass to `docc`. ParsedArguments will merge the flags provided
            // by the user with default fallback values for required flags that were not
            // provided.
            let doccArguments = parsedArguments.doccArguments(
                action: .convert,
                targetKind: target.kind == .executable ? .executable : .library,
                doccCatalogPath: target.doccCatalogPath,
                targetName: target.name,
                symbolGraphDirectoryPath: symbolGraphs.unifiedSymbolGraphsDirectory.path,
                outputPath: doccArchiveOutputPath
            )

            print("Converting documentation...")
            let conversionStartTime = DispatchTime.now()

            // Run `docc convert` with the generated arguments and wait until the process completes
            let process = try Process.run(doccExecutableURL, arguments: doccArguments)
            process.waitUntilExit()

            let conversionDuration = conversionStartTime.distance(to: .now())

            // Check whether the `docc convert` invocation was successful.
            if process.terminationReason == .exit, process.terminationStatus == 0 {
                print("Conversion complete! (\(conversionDuration.descriptionInSeconds))")

                let describedOutputPath = doccArguments.outputPath ?? "unknown location"
                print("Generated DocC archive at '\(describedOutputPath)'")
            } else {
                Diagnostics.error("""
                    'docc convert' invocation failed with a nonzero exit code: '\(process.terminationStatus)'
                    """
                )
                return false
            }
        }

        if swiftSourceModuleTargets.count > 1 {
            print("\nMultiple DocC archives generated at '\(context.pluginWorkDirectory.string)'")
        }

        print(String(repeating: "-", count: 40) + "\n\n")

        return true
    }
}

extension ArgumentExtractor {
    mutating func mainTarget() -> String? {
        extractOption(named: "main-target").first
    }

    mutating func targets() -> [String] {
        extractOption(named: "target")
    }

    mutating func outputDirectory() -> String? {
        extractOption(named: "output").first
    }
}
