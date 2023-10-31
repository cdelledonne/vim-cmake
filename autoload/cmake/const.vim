" ==============================================================================
" Location:    autoload/cmake/const.vim
" Description: Constants and definitions
" ==============================================================================

let s:const = {}

let s:const.plugin_version = '0.12.1'

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
