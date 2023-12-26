" ==============================================================================
" File:        cmake.vim
" Description: Vim-CMake, a Vim/Neovim plugin for working with CMake projects
" Maintainer:  Carlo Delle Donne <https://github.com/cdelledonne>
" Version:     0.15.1
" License:     MIT
" ==============================================================================

if exists('g:loaded_cmake') && g:loaded_cmake
    finish
endif
let g:loaded_cmake = 1

" Assign user/default values to coniguration variables.
" NOTE: must be done before loading other scripts.
let s:const = cmake#const#Get()
for s:cvar in items(s:const.config_vars)
    if !has_key(g:, s:cvar[0])
        let g:[s:cvar[0]] = s:cvar[1]
    endif
endfor

" Configure logger.
let s:logger = libs#logger#Get(
    \ s:const.plugin_name,
    \ s:const.echo_prefix,
    \ g:cmake_log_file,
    \ g:cmake_log_level
    \ )

" Configure error reporter.
let s:error = libs#error#Get(s:const.plugin_name, s:logger)
call s:error.ExtendDatabase(s:const.errors)

" Check required features.
if has('nvim')
    if !has('nvim-0.5.0')
        call s:error.Throw('OLD_NEOVIM')
        finish
    endif
else
    if has('win32')
        call s:error.Throw('VIM_WINDOWS')
        finish
    endif
    if !has('terminal')
        call s:error.Throw('NO_TERMINAL')
        finish
    endif
endif

call s:logger.LogInfo('Loading Vim-CMake')

" Check if CMake executable exists.
if !executable(g:cmake_command)
    call s:error.Throw('NO_CMAKE', g:cmake_command)
    finish
endif

" Check if CTest executable exists.
if !executable(g:cmake_test_command)
    call s:error.Throw('NO_CTEST', g:cmake_test_command)
    finish
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -nargs=? -bang CMakeGenerate call cmake#Generate(<bang>0, <f-args>)
command -nargs=? CMakeClean call cmake#Clean()
command -nargs=1 -complete=custom,cmake#GetConfigs CMakeSwitch call cmake#Switch(<f-args>)

command -nargs=? -bang -complete=custom,cmake#GetBuildTargets CMakeBuild call cmake#Build(<bang>0, <f-args>)
command CMakeInstall call cmake#Install()

command -nargs=+ -complete=custom,cmake#GetExecTargets CMakeRun call cmake#Run(<f-args>)

command -nargs=? -complete=custom,cmake#GetTests CMakeTest call cmake#Test(<f-args>)

command CMakeOpen call cmake#Open()
command -bang CMakeClose call cmake#Close(<bang>0)
command CMakeToggle call cmake#Toggle()
command CMakeCloseOverlay call cmake#CloseOverlay()
command CMakeStop call cmake#Stop()

call s:logger.LogInfo('Commands defined')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

nnoremap <silent> <Plug>(CMakeGenerate) :call cmake#Generate(v:false)<CR>
nnoremap <silent> <Plug>(CMakeClean) :call cmake#Clean()<CR>
nnoremap <Plug>(CMakeSwitch) :CMakeSwitch<Space>

nnoremap <silent> <Plug>(CMakeBuild) :call cmake#Build(v:false)<CR>
nnoremap <silent> <Plug>(CMakeInstall) :call cmake#Install()<CR>
nnoremap <Plug>(CMakeBuildTarget) :CMakeBuild<Space>

nnoremap <Plug>(CMakeRun) :CMakeRun<Space>

nnoremap <silent> <Plug>(CMakeTest) :call cmake#Test()<CR>

nnoremap <silent> <Plug>(CMakeOpen) :call cmake#Open()<CR>
nnoremap <silent> <Plug>(CMakeClose) :call cmake#Close(v:false)<CR>
nnoremap <silent> <Plug>(CMakeToggle) :call cmake#Toggle()<CR>
nnoremap <silent> <Plug>(CMakeCloseOverlay) :call cmake#CloseOverlay()<CR>
nnoremap <silent> <Plug>(CMakeStop) :call cmake#Stop()<CR>

call s:logger.LogInfo('Mappings defined')

call s:logger.LogInfo('Vim-CMake loaded')
