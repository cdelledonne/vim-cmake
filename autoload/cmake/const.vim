" ==============================================================================
" Location:    autoload/cmake/const.vim
" Description: Constants and definitions
" ==============================================================================

let s:const = {}

let s:const.plugin_name = 'cmake'
let s:const.plugin_version = '0.15.2'

let s:const.echo_prefix = '[Vim-CMake] '

let s:const.plugin_news = {
    \ '0.2.0': ['Vim-CMake has a new feature, run `:help cmake-switch`'],
    \ '0.3.0': ['Vim-CMake has a new feature, run `:help cmake-quickfix`'],
    \ '0.4.0': ['Vim-CMake has a new config option `g:cmake_generate_options`'],
    \ '0.5.0': ['Vim-CMake has a new feature, run `:help cmake-events`'],
    \ '0.6.0': [
        \ 'Vim-CMake has a new config option `g:cmake_build_dir_location`',
        \ 'Vim-CMake has improved :CMakeGenerate, run `:help cmake-generate`'
    \ ],
    \ '0.7.0': [
        \ 'Vim-CMake has new command `:CMakeStop`, run `:help cmake-stop`',
        \ 'Vim-CMake has a new config option `g:cmake_console_echo_cmd`'
    \ ],
    \ '0.8.0': ['Vim-CMake has a new feature, run `:help cmake-test`'],
    \ '0.9.0': ['Vim-CMake has a new API function, run `:help cmake-api`'],
    \ '0.10.0': ['Vim-CMake has a new config option `g:cmake_restore_state`'],
    \ '0.11.0': ['Vim-CMake has more autocmds, run `:help cmake-events`'],
    \ '0.13.0': ['Vim-CMake has new command `:CMakeToggle`, run `:help :CMakeToggle`'],
    \ '0.14.0': ['Vim-CMake has new command `:CMakeRun`, run `:help :CMakeRun`'],
    \ }

let s:const.errors = {
    \ 'CANT_STOP_CONSOLE_JOB':
    \     'Cannot stop the CMake console job while a command is running',
    \ 'CANT_STOP_OVERLAY_JOB':
    \     'Cannot stop the CMake overlay job while a command is running',
    \ 'COMMAND_RUNNING':
    \     'Another CMake command is already running',
    \ 'COMMAND_RUNNING_OVERLAY':
    \     'Another command is already running',
    \ 'FILEAPI_NORESP':
    \     'fileapi: Response from cmake-file-api(7) missing. Target completion will not work. Run :CMakeGenerate',
    \ 'FILEAPI_RERUN':
    \     'fileapi: Response from cmake-file-api(7) out of date. Some functionality may not work correctly. Run :CMakeGenerate',
    \ 'FILEAPI_VERSION':
    \     'fileapi: CMake version not supported. Certain functionality will not work correctly. (Minimum supported is CMake 3.14)',
    \ 'NOT_EXECUTABLE':
    \     'File ''%s'' is not executable',
    \ 'NO_CMAKE':
    \     'CMake binary ''%s'' not found in PATH',
    \ 'NO_CONFIG':
    \     'Build configuration ''%s'' not found, run '':CMakeGenerate %s''',
    \ 'NO_CTEST':
    \     'CTest binary ''%s'' not found in PATH',
    \ 'NO_EXEC_PATH':
    \     'Executable ''%s'' does not exist, try building project',
    \ 'NO_EXEC_TARGET':
    \     'Target ''%s'' does not exist or is not an executable target',
    \ 'NO_TERMINAL':
    \     'Must run Neovim, or Vim with +terminal',
    \ 'OLD_NEOVIM':
    \     'Only Neovim versions >= 0.5 are supported',
    \ 'VIM_WINDOWS':
    \     'Under Windows, only Neovim is supported at the moment',
    \ }

let s:const.config_vars = {}
let s:const.config_vars.cmake_command               = 'cmake'
let s:const.config_vars.cmake_test_command          = 'ctest'
let s:const.config_vars.cmake_default_config        = 'Debug'
let s:const.config_vars.cmake_build_dir_location    = '.'
let s:const.config_vars.cmake_generate_options      = []
let s:const.config_vars.cmake_build_options         = []
let s:const.config_vars.cmake_native_build_options  = []
let s:const.config_vars.cmake_test_options          = []
let s:const.config_vars.cmake_console_size          = 15
let s:const.config_vars.cmake_console_position      = 'botright'
let s:const.config_vars.cmake_console_echo_cmd      = 1
let s:const.config_vars.cmake_jump                  = 0
let s:const.config_vars.cmake_jump_on_completion    = 0
let s:const.config_vars.cmake_jump_on_error         = 1
let s:const.config_vars.cmake_link_compile_commands = 0
let s:const.config_vars.cmake_root_markers          = ['.git', '.svn']
let s:const.config_vars.cmake_log_file              = ''
let s:const.config_vars.cmake_log_level             = 'INFO'
let s:const.config_vars.cmake_statusline            = 0
let s:const.config_vars.cmake_restore_state         = 1
let s:const.config_vars.cmake_reinit_on_dir_changed = 1

" Get const 'object'.
"
function! cmake#const#Get() abort
    return s:const
endfunction
