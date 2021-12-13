# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][format], and this project adheres to
[Semantic Versioning][semver].

## Unreleased

### Changed
* Fixed searching of root path and build directory location
* Detecting CMake version now works also for packages which are not called just
  `cmake` (for instance, the `cmake3` package in the `epel` repo)

<!--=========================================================================-->

## 0.6.2 &ndash; 2021-08-02

### Changed
* `-DCMAKE_BUILD_TYPE` flag is now always added when running `:CMakeGenerate`
* The hashbang for `bash` in `scripts/console.sh` has been made more portable by
  using `/usr/bin/env`.

<!--=========================================================================-->

## 0.6.1 &ndash; 2021-06-19

### Added
* Set `bufhidden=hide` on the Vim-CMake buffer to avoid error E37 in some Vim
  instances.

### Changed
* Running a command does not result in jumping into the Vim-CMake window and
  back in the background, thus reducing the number of unnecessarily triggered
  events.

<!--=========================================================================-->

## 0.6.0 &ndash; 2021-04-14

### Added
* `g:cmake_build_dir_location`, location of the build directory, relative to the
  project root.

### Changed
* Usage of `:CMakeGenerate`, now build configuration directory and
  `CMAKE_BUILD_TYPE` can be controlled independently.

<!--=========================================================================-->

## 0.5.0 &ndash; 2021-02-22

### Added
* Implemented user autocommands `CMakeBuildFailed` and `CMakeBuildSuceeded` to
  customize behaviour after `:CMakeBuild`

### Changed
* Fixed bug that wouldn't make the console script run when Vim-CMake is
  installed in a directory that contains spaces.
* Make the `WinEnter` autocmd in console.vim buffer-local.
* Set correct source and build directories even when invoking Vim-CMake commands
  from subdirectory of root (source) directory.
* Internal implementation of `:CMakeGenerate` made more structured.
* Automatically set the configuration option `CMAKE_EXPORT_COMPILE_COMMANDS` to
  `ON` when `g:cmake_link_compile_commands` is set to `1`.
* Pass job callbacks directly to `jobstart`/`termopen`.

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
