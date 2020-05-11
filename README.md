# Vim-CMake

Vim-CMake is a plugin for building CMake projects inside of Vim/Neovim, with a
nice visual feedback.

![screencast][screencast]

**Features**

* Visual experience, shows CMake output in a console-like window
* Plug-and-play, but configurable
* Autocompletion for build targets
* Airline status information, including current build type
* Written in Vimscript (other than one tiny Bash script)

**Requirements**

* Vim with `+terminal`, or Neovim
* Linux or macOS (Windows not supported/tested yet)

**Related projects**

* [vhdirk/vim-cmake][vim-cmake]
* [ilyachur/cmake4vim][cmake4vim]
* [jalcine/cmake.vim][cmake.vim]
* [sigidagi/vim-cmake-project][vim-cmake-project]
* [LucHermitte/vim-build-tools-wrapper][LucHermitte/vim-build-tools-wrapper]
* [kassio/neoterm][neoterm]

<!--=========================================================================-->

## Installation

Use a package manager like [vim-plug][vim-plug]:

```vim
Plug 'cdelledonne/vim-cmake'
```

or Vim's native package manager:

```sh
mkdir -p ~/.vim/pack/plug/start
cd ~/.vim/pack/plug/start
git clone https://github.com/cdelledonne/vim-cmake.git
vim -u NONE -c "helptags vim-cmake/doc | q"
```

<!--=========================================================================-->

## Usage

Run `:CMakeGenerate` from the top-level CMake source directory to generate a
build system for the project.  Then, run `:CMakeBuild` to build the project. The
built files will end up in the binary directory ([out-of-source build][oos]).

With Vim-CMake, you can easily manage build types (Debug, Release, etc.), build
specific targets and control build options.  For a detailed explanation of
commands and mappings run `:help cmake`.  A quick overview follows.

### Commands and `<Plug>` mappings

| Command                   | `<Plug>` mapping    | Description                                |
|:--------------------------|:--------------------|:-------------------------------------------|
| `:CMakeGenerate[!]`       | `(CMakeGenerate)`   | Generate build system                      |
| `:CMakeClean`             | `(CMakeClean)`      | Remove build system and build files        |
| `:CMakeBuild[!] [target]` | `(CMakeBuild)`      | Build a project                            |
| `:CMakeBuildClean`        | `(CMakeBuildClean)` | Remove build files (like `make clean`)     |
| `:CMakeInstall`           | `(CMakeInstall)`    | Install build output (like `make install`) |
| `:CMakeOpen`              | `(CMakeOpen)`       | Open CMake console window                  |
| `:CMakeClose`             | `(CMakeClose)`      | Close CMake console window                 |

### Additional `<Plug>` mappings

| `<Plug>` mapping     | Behaves as                                            |
|:---------------------|:------------------------------------------------------|
| `(CMakeBuildTarget)` | `(CMakeBuild)`, but leaves cursor in the command line |

### Key mappings in the CMake console window

| Key mapping | Description                |
|:------------|:---------------------------|
| `cg`        | Run `:CMakeGenerate`       |
| `cb`        | Run `:CMakeBuild`          |
| `cc`        | Run `:CMakeBuildClean`     |
| `ci`        | Run `:CMakeInstall`        |
| `cq`        | Close CMake console window |
| `<C-C>`     | Stop current command       |

<!--=========================================================================-->

## Configuration

Vim-CMake has sensible defaults. Again, run `:help cmake` for an extensive
documentation of all the configuration options.  A list of default values
follows.

| Options                         | Default            |
|:--------------------------------|:-------------------|
| `g:cmake_command`               | `'cmake'`          |
| `g:cmake_default_build_dir`     | `'build'`          |
| `g:cmake_build_options`         | `[]`               |
| `g:cmake_native_build_options`  | `[]`               |
| `g:cmake_console_size`          | `15`               |
| `g:cmake_console_position`      | `'botright'`       |
| `g:cmake_jump`                  | `0`                |
| `g:cmake_jump_on_completion`    | `0`                |
| `g:cmake_jump_on_error`         | `1`                |
| `g:cmake_link_compile_commands` | `0`                |
| `g:cmake_root_markers`          | `['.git', '.svn']` |

<!--=========================================================================-->

## Contributing

Feedback and feature requests are appreciated.  Bug reports and pull requests
are very welcome.  Check the [Contributing Guidelines][contributing] for how to
write a feature request, post an issue or submit a pull request.

<!--=========================================================================-->

## Known issues

#### Airline status information not working

So far, I haven't been able to bypass Airline's terminal extension in an elegant
way.  As a temporary workaround, set the following in your `.vimrc` (or
`init.vim`) to disable the extension altogether:
```vim
let g:airline#extensions#term#enabled = 0
```

<!--=========================================================================-->

## License

Vim-CMake is licensed under the [MIT license][license].  Copyright (c) 2020
Carlo Delle Donne.

<!--=========================================================================-->

[screencast]: https://user-images.githubusercontent.com/24732205/81405504-12555600-9138-11ea-8fca-c93ceb64dca3.gif
[vim-cmake]: https://github.com/vhdirk/vim-cmake
[cmake4vim]: https://github.com/ilyachur/cmake4vim
[cmake.vim]: https://github.com/jalcine/cmake.vim
[vim-cmake-project]: https://github.com/sigidagi/vim-cmake-project
[LucHermitte/vim-build-tools-wrapper]: https://github.com/LucHermitte/vim-build-tools-wrapper
[neoterm]: https://github.com/kassio/neoterm
[vim-plug]: https://github.com/junegunn/vim-plug
[oos]: https://cprieto.com/posts/2016/10/cmake-out-of-source-build.html
[contributing]: ./CONTRIBUTING.md
[license]: ./LICENSE
