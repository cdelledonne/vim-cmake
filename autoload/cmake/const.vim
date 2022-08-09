" ==============================================================================
" Location:    autoload/cmake/const.vim
" Description: Constants and definitions
" ==============================================================================

let s:const = {}

let s:const.plugin_version = '0.9.0'

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
    \ }

let s:const.config_vars = {
        \ 'cmake_command'               : 'cmake',
        \ 'cmake_test_command'          : 'ctest',
        \ 'cmake_default_config'        : 'Debug',
        \ 'cmake_build_dir_location'    : '.',
        \ 'cmake_generate_options'      : [],
        \ 'cmake_build_options'         : [],
        \ 'cmake_native_build_options'  : [],
        \ 'cmake_test_options'          : [],
        \ 'cmake_console_size'          : 15,
        \ 'cmake_console_position'      : 'botright',
        \ 'cmake_console_echo_cmd'      : 1,
        \ 'cmake_jump'                  : 0,
        \ 'cmake_jump_on_completion'    : 0,
        \ 'cmake_jump_on_error'         : 1,
        \ 'cmake_link_compile_commands' : 0,
        \ 'cmake_root_markers'          : ['.git', '.svn'],
        \ 'cmake_log_file'              : '',
        \ 'cmake_statusline'            : 0,
        \ 'cmake_restore_state'         : 1,
        \ }

" Get const 'object'.
"
function! cmake#const#Get() abort
    return s:const
endfunction
