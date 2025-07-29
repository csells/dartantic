# Welcome to dartantic_interface!

This repo contains the implementation for the
[dartantic_interface](https://pub.dev/packages/dartantic_interface) package. It
forms the base set of interfaces used to implement providers and chat and
embeddings models for [dartantic_ai](https://pub.dev/packages/dartantic_ai). 

By implementing a custom provider based on dartantic_interface, you do not need
to depend on all of dartantic_ai. Likewise, your provider does not need to be
multi-platform or support wasm, as is the requirement for providers built into
dartantic_ai.
