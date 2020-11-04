# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][format], and this project adheres to
[Semantic Versioning][semver].

<!--=========================================================================-->

## Unreleased

### Changed
* Fixed bug that wouldn't make the console script run when Vim-CMake is
  installed in a directory that contains spaces.
* Make the `WinEnter` autocmd in console.vim buffer-local.
* Set correct source and build directories even when invoking Vim-CMake commands
  from subdirectory of root (source) directory.

<!--=========================================================================-->

## 0.4.0 &ndash; 2020-10-13

### Added
* `g:cmake_generate_options`, list of options to pass to CMake by default when
  running `:CMakeGenerate`.

### Changed
* Fixed parsing command output in Vim to populate the quickfix list.
* Updated source code documentation format.

<!--=========================================================================-->

## 0.3.0 &ndash; 2020-09-01

### Added
* Quickfix list population after each build.

<!--=========================================================================-->

## 0.2.2 &ndash; 2020-07-18

### Changed
* Support for Airline is now provided in the vim-airline plugin, and disabling
  Airline's terminal extension is not needed anymore.

<!--=========================================================================-->

## 0.2.1 &ndash; 2020-07-15

### Changed
* Pass absolute path to `findfile()` when searching for existing build
  configurations.

<!--=========================================================================-->

## 0.2.0 &ndash; 2020-07-12

### Added
* `:CMakeSwitch` command, and `<Plug>(CMakeSwitch)` mapping, to switch between
  build configurations.
* `g:cmake_default_config`, the default build configuration on start-up.
* Print Vim-CMake updates when new version is pulled.

### Changed
* `:CMakeGenerate` can be called with build configuration as a direct option,
  e.g., `:CMakeGenerate Release`.

### Removed
* `g:cmake_default_build_dir`.

<!--=========================================================================-->

## 0.1.1 &ndash; 2020-06-11

### Changed
* `:CMakeBuild!` and `:CMakeInstall` now use the native `--clean-first` and
  `--install` CMake options.
* Fix error when vim-airline not loaded and polish statusline/Airline output.

### Removed
* `:CMakeBuildClean`, as `:CMakeBuild!` should cover most of the use cases, and
  `:CMakeBuild clean` can still be used.

<!--=========================================================================-->

## 0.1.0 &ndash; 2020-05-09

First version.

<!--=========================================================================-->

[format]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html
