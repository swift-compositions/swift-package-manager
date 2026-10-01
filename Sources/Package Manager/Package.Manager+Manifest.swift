private import JSON
public import SPM_Standard

extension Package.Manager {

    public func manifest(
        at directory: Swift.String,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Manifest {
        let json = try dump(at: directory, timeout: timeout, scratch: scratch)
        do throws(JSON.Error) {
            return try decode(json)
        } catch {
            throw .manifest
        }
    }

    private func decode(_ json: JSON) throws(JSON.Error) -> Package.Manifest {
        guard json.isObject else {
            throw .typeMismatch(expected: "Manifest object", got: "non-object JSON value")
        }
        let nameValue = json["name"]
        guard nameValue.isString else { throw .missingKey("name") }

        let versionValue = json["toolsVersion"]["_version"]
        guard versionValue.isString else { throw .missingKey("toolsVersion._version") }
        let version = try tools(Swift.String(versionValue))

        guard let values = json["dependencies"].array else {
            throw .missingKey("dependencies")
        }
        var dependencies: [Package.Dependency] = []
        dependencies.reserveCapacity(values.count)
        for value in values {
            dependencies.append(try dependency(value))
        }

        return Package.Manifest(
            name: Package.Name(_unchecked: Swift.String(nameValue)),
            toolsVersion: version,
            dependencies: dependencies
        )
    }

    private func dependency(_ json: JSON) throws(JSON.Error) -> Package.Dependency {
        guard json.isObject else {
            throw .typeMismatch(expected: "dependency object", got: "non-object JSON value")
        }

        if let record = json["fileSystem"].array?.first {
            let identity = try string(record["identity"], key: "fileSystem.identity")
            let path = try string(record["path"], key: "fileSystem.path")
            return .init(
                source: .path(path),
                name: Package.Name(_unchecked: identity),
                products: []
            )
        }

        if let record = json["sourceControl"].array?.first {
            let identity = try string(record["identity"], key: "sourceControl.identity")
            let remotes = record["location"]["remote"].array ?? []
            let value: Swift.String
            if let remote = remotes.first {
                value = try string(
                    remote["urlString"],
                    key: "sourceControl.location.remote.urlString"
                )
            } else {
                value = ""
            }
            let uri: URI
            do throws(URIError) {
                uri = try URI(value)
            } catch {
                throw .typeMismatch(expected: "valid URI per RFC 3986", got: value)
            }
            return .init(
                source: .url(uri, try requirement(record["requirement"])),
                name: Package.Name(_unchecked: identity),
                products: []
            )
        }

        if let record = json["registry"].array?.first {
            let value = try string(record["identity"], key: "registry.identity")
            return .init(
                source: .registry(try identity(value), try requirement(record["requirement"])),
                name: Package.Name(_unchecked: value),
                products: []
            )
        }

        throw .typeMismatch(
            expected: "fileSystem|sourceControl|registry dependency",
            got: "object without a dependency discriminator"
        )
    }

    private func requirement(_ json: JSON) throws(JSON.Error) -> Package.Requirement {
        guard json.isObject else {
            throw .typeMismatch(expected: "requirement object", got: "non-object JSON value")
        }
        if let value = json["exact"].array?.first {
            return .exact(try semantic(try string(value, key: "exact[0]")))
        }
        if let value = json["range"].array?.first {
            let lower = try semantic(try string(value["lowerBound"], key: "range.lowerBound"))
            let upper = try semantic(try string(value["upperBound"], key: "range.upperBound"))
            return lower..<upper
        }
        if let value = json["branch"].array?.first {
            return .branch(try string(value, key: "branch[0]"))
        }
        if let value = json["revision"].array?.first {
            return .revision(try string(value, key: "revision[0]"))
        }
        throw .typeMismatch(
            expected: "exact|range|branch|revision requirement",
            got: "object without a requirement discriminator"
        )
    }

    private func string(_ json: JSON, key: Swift.String) throws(JSON.Error) -> Swift.String {
        guard json.isString else { throw .missingKey(key) }
        return Swift.String(json)
    }

    private func tools(_ value: Swift.String) throws(JSON.Error) -> Version.Tools {
        var input = [Byte](utf8: value)[...]
        let parsed: Version.Tools?
        do throws(Version.Tools.ParserError) {
            parsed = try Version.Tools.parser.parse(&input)
        } catch {
            parsed = nil
        }
        guard let parsed, input.isEmpty else {
            throw .typeMismatch(expected: "valid swift-tools-version", got: value)
        }
        return parsed
    }

    private func semantic(_ value: Swift.String) throws(JSON.Error) -> Version.Semantic {
        var input = [Byte](utf8: value)[...]
        let parsed: Version.Semantic?
        do throws(Version.Semantic.ParserError) {
            parsed = try Version.Semantic.parser.parse(&input)
        } catch {
            parsed = nil
        }
        guard let parsed, input.isEmpty else {
            throw .typeMismatch(expected: "valid semantic version", got: value)
        }
        return parsed
    }

    private func identity(_ value: Swift.String) throws(JSON.Error) -> Package.Identity {
        guard let dot = value.firstIndex(of: ".") else {
            throw .typeMismatch(expected: "registry identity 'scope.name'", got: value)
        }
        return .init(
            scope: Swift.String(value[..<dot]),
            name: Swift.String(value[value.index(after: dot)...])
        )
    }
}
