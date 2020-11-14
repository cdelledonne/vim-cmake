" ==============================================================================
" File:        cmake.vim
" Description: Vim-CMake, a Vim/Neovim plugin for working with CMake projects
" Maintainer:  Carlo Delle Donne <https://github.com/cdelledonne>
" Version:     0.4.0
" License:     MIT
" ==============================================================================

if exists('g:loaded_cmake') && g:loaded_cmake
    finish
endif
let g:loaded_cmake = 1

let g:cmake_command = get(g:, 'cmake_command', 'cmake')

if !executable(g:cmake_command)
    call cmake#util#Log('E', 'Binary "' . g:cmake_command . '" not found in PATH')
    finish
endif

if !has('nvim') && !has('terminal')
    call cmake#util#Log('E', 'Must run Neovim, or Vim with +terminal')
    finish
endif

let s:config_vars = {
        \ 'g:cmake_default_config'        : 'Debug',
        \ 'g:cmake_build_directory'       : '.',
        \ 'g:cmake_generate_options'      : [],
        \ 'g:cmake_build_options'         : [],
        \ 'g:cmake_native_build_options'  : [],
        \ 'g:cmake_console_size'          : 15,
        \ 'g:cmake_console_position'      : 'botright',
        \ 'g:cmake_jump'                  : 0,
        \ 'g:cmake_jump_on_completion'    : 0,
        \ 'g:cmake_jump_on_error'         : 1,
        \ 'g:cmake_link_compile_commands' : 0,
        \ 'g:cmake_root_markers'          : ['.git', '.svn'],
        \ }

" Assign user/default values to coniguration variables.
for s:cvar in items(s:config_vars)
    if !exists(s:cvar[0])
        let {s:cvar[0]} = s:cvar[1]
    else
        if type({s:cvar[0]}) is# v:t_list
            call extend({s:cvar[0]}, s:cvar[1])
        endif
    endif
endfor

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -nargs=? -bang CMakeGenerate call cmake#Generate(0, 0, <bang>0, <f-args>)
command -nargs=? CMakeClean call cmake#Clean()

command -nargs=1 -complete=custom,cmake#switch#GetExistingConfigs CMakeSwitch
        \ call cmake#Switch(<f-args>)

command -nargs=? -bang -complete=custom,cmake#build#GetTargets CMakeBuild
        \ call cmake#Build(0, 0, <bang>0, <f-args>)

command CMakeInstall call cmake#Install(0, 0)

command CMakeOpen call cmake#Open()
command CMakeClose call cmake#Close()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

nnoremap <silent> <Plug>(CMakeGenerate) :call cmake#Generate(0, 0, 0)<CR>
nnoremap <silent> <Plug>(CMakeClean) :call cmake#Clean()<CR>

nnoremap <silent> <Plug>(CMakeBuild) :call cmake#Build(0, 0, 0)<CR>
nnoremap <silent> <Plug>(CMakeInstall) :call cmake#Install(0, 0)<CR>
nnoremap <Plug>(CMakeBuildTarget) :CMakeBuild<Space>

nnoremap <Plug>(CMakeSwitch) :CMakeSwitch<Space>

nnoremap <silent> <Plug>(CMakeOpen) :call cmake#console#Open(0)<CR>
nnoremap <silent> <Plug>(CMakeClose) :call cmake#console#Close()<CR>
