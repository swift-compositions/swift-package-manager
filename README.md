# swift-package-manager

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Foundation-free SwiftPM operations through the installed Swift toolchain.

---

## Quick Start

Evaluate a package manifest through SwiftPM and receive the Layer-2 manifest model:

```swift
import Package_Manager

let manager = Package.Manager()
let manifest = try manager.manifest(at: "/path/to/package")

print(manifest.name)
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-package-manager.git", branch: "main")
]
```

Use the `Package Manager` product and import `Package_Manager`.

### Requirements

- Swift 6.3+
- macOS 26+
- An installed Swift toolchain

---

## Architecture

`Package.Manager` owns operational SwiftPM interaction. It invokes `swift package dump-package` through [swift-process](https://github.com/swift-compositions/swift-process), parses output through [swift-json](https://github.com/swift-compositions/swift-json), and returns the external SwiftPM representations in [swift-spm-standard](https://github.com/swift-standards/swift-spm-standard).

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at the first public release.*
<!-- END: discussion -->

---

## License

Apache 2.0. See [LICENSE](LICENSE.md).
