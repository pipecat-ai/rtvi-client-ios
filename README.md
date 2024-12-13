<h1><div align="center">
 <img alt="pipecat" width="500px" height="auto" src="https://raw.githubusercontent.com/pipecat-ai/pipecat-client-ios/main/pipecat-ios.png">
</div></h1>

[![Docs](https://img.shields.io/badge/Documentation-blue)](https://docs.pipecat.ai/client/reference/ios/introduction) [![Discord](https://img.shields.io/discord/1239284677165056021)](https://discord.gg/pipecat)

The official iOS client SDK for [Pipecat](https://github.com/pipecat-ai/pipecat), an open source Python framework for building voice and multimodal AI applications.

## Overview

The Pipecat iOS SDK provides a Swift implementation for building voice and multimodal AI applications on iOS.

The SDK handles:

- Device and media stream management
- Managing bot configuration
- Sending generic actions to the bot
- Handling bot messages and responses
- Managing session state and errors

To connect to a bot, you will need both this SDK and a transport implementation.

**Transport packages:**

For connected use-cases, you must pass a transport instance to the constructor for your chosen protocol or provider.

For example, if you were looking to use WebRTC as a transport layer, you may use a provider like [Daily](https://daily.co). In this scenario, you’d construct a transport instance and pass it to the client accordingly:

```swift
let client = VoiceClient(baseUrl: "your-api-url", transport: YOUR_TRANSPORT, options: options)
try await client.connect()
```

## Install

To depend on the client package, you can add this package via Xcode's package manager using the URL of this git repository directly, or you can declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/pipecat-ai/pipecat-client-ios.git", from: "0.3.0"),
```

and add `"PipecatClientIOS"` to your application/library target, `dependencies`, e.g. like this:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "PipecatClientIOS", package: "pipecat-client-ios")
],
```

## Contributing

We welcome contributions from the community! Whether you're fixing bugs, improving documentation, or adding new features, here's how you can help:

- **Found a bug?** Open an [issue](https://github.com/pipecat-ai/pipecat-client-ios/issues)
- **Have a feature idea?** Start a [discussion](https://discord.gg/pipecat)
- **Want to contribute code?** Check our [CONTRIBUTING.md](CONTRIBUTING.md) guide
- **Documentation improvements?** [Docs](https://github.com/pipecat-ai/docs) PRs are always welcome

Before submitting a pull request, please check existing issues and PRs to avoid duplicates.

We aim to review all contributions promptly and provide constructive feedback to help get your changes merged.

## Getting help

➡️ [Join our Discord](https://discord.gg/pipecat)

➡️ [Read the docs](https://docs.pipecat.ai)
