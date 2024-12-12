<h1><div align="center">
 <img alt="pipecat" width="500px" height="auto" src="https://raw.githubusercontent.com/pipecat-ai/pipecat-client-ios/main/pipecat-ios.png">
</div></h1>

The [Pipecat](https://github.com/pipecat-ai/) project uses [RTVI-AI](https://github.com/rtvi-ai/), an open standard for Real-Time Voice [and Video] Inference.

This iOS core library exports a VoiceClient that has no associated transport.

When building an RTVI application, you should use your transport-specific export (see [here](https://rtvi.mintlify.app/api-reference/transports/introduction) for available first-party packages.) 
The base class has no out-of-the-box bindings included.

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

## References
- [RTVI-AI overview](https://github.com/rtvi-ai/).
- [RTVI-AI reference docs](https://rtvi.mintlify.app/api-reference/introduction).
- [rtvi-client-ios SDK docs](https://rtvi-client-ios-docs.vercel.app/RTVIClientIOS/documentation/rtviclientios).
- [rtvi-client-ios-daily SDK docs](https://rtvi-client-ios-docs.vercel.app/RTVIClientIOSDaily/documentation/rtviclientiosdaily).

## Contributing

We are welcoming contributions to this project in form of issues and pull request. For questions about RTVI head over to the [Pipecat discord server](https://discord.gg/pipecat) and check the [#rtvi](https://discord.com/channels/1239284677165056021/1265086477964935218) channel.
