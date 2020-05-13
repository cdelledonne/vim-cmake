# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][format], and this project adheres to
[Semantic Versioning][semver].

<!--=========================================================================-->

## Unreleased

### Changed
* `:CMakeBuild!` and `:CMakeInstall` now use the native `--clean-first` and
  `--install` CMake options.

### Removed
* `:CMakeBuildClean`, as `:CMakeBuild!` should cover most of the use cases, and
  `:CMakeBuild clean` can still be used.

<!--=========================================================================-->

## 0.1.0 -- 2020-05-09

First version.

<!--=========================================================================-->

[format]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html
