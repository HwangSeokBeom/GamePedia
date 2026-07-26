fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ci_build

```sh
[bundle exec] fastlane ios ci_build
```

Build and test the iOS app for CI

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build the staging app and upload it to TestFlight

### ios release_archive

```sh
[bundle exec] fastlane ios release_archive
```

Validate the production archive path on main without uploading

### ios release_preflight

```sh
[bundle exec] fastlane ios release_preflight
```

Validate the production Release build without creating an archive

### ios release

```sh
[bundle exec] fastlane ios release
```

Build the production app and upload it to App Store Connect only when explicitly triggered

### ios release_upload

```sh
[bundle exec] fastlane ios release_upload
```

Compatibility alias for the production upload lane

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
