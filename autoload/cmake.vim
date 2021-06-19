" ==============================================================================
" Location:    autoload/cmake.vim
" Description: API functions and global data for Vim-CMake
" ==============================================================================

let s:plugin_version = '0.6.1'

" Print news of new Vim-CMake versions.
call cmake#plugnews#Print(s:plugin_version, {
        \ '0.2.0': ['Vim-CMake has a new feature, run `:help cmake-switch`'],
        \ '0.3.0': ['Vim-CMake has a new feature, run `:help cmake-quickfix`'],
        \ '0.4.0': ['Vim-CMake has a new config option `g:cmake_generate_options`'],
        \ '0.5.0': ['Vim-CMake has a new feature, run `:help cmake-events`'],
        \ '0.6.0': [
                \ 'Vim-CMake has a new config option `g:cmake_build_dir_location`',
                \ 'Vim-CMake has improved :CMakeGenerate, run `:help cmake-generate`'
        \ ],
        \ })

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" API function for cmake#generate#Run().
"
" Params:
"     bg : Number
"         whether to run the command in the background
"     wait : Number
"         whether to wait for completion (only for bg == 1)
"     clean : Number
"         whether to clean before generating
"     a:1 : String
"         (optional) build configuration and additional CMake options
"
function! cmake#Generate(bg, wait, clean, ...) abort
    if a:0 > 0
        call cmake#generate#Run(a:bg, a:wait, a:clean, a:1)
    else
        call cmake#generate#Run(a:bg, a:wait, a:clean)
    endif
endfunction

" API function for cmake#generate#Clean().
"
function! cmake#Clean() abort
    call cmake#generate#Clean()
endfunction

" API function for cmake#switch#SetCurrentConfigName().
"
" Params:
"     a:1 : String
"         build configuration
"
function! cmake#Switch(...) abort
    " Check that config folder exists.
    let l:configs = split(cmake#switch#GetExistingConfigs('', '', 0))
    if index(l:configs, a:1) == -1
        call cmake#util#Log('W', 'Build configuration "' . a:1 .
                \ '" not found, run `:CMakeGenerate ' . a:1 . '`')
        return
    endif
    call cmake#switch#SetCurrentConfigName(a:1)
endfunction

" API function for cmake#build#Run().
"
" Params:
"     bg : Number
"         whether to run the command in the background
"     wait : Number
"         whether to wait for completion (only for bg == 1)
"     clean : Number
"         whether to clean before building
"     a:1 : String
"         (optional) target and other build options
"
function! cmake#Build(bg, wait, clean, ...) abort
    if a:0 > 0
        call cmake#build#Run(a:bg, a:wait, a:clean, a:1)
    else
        call cmake#build#Run(a:bg, a:wait, a:clean)
    endif
endfunction

" API function for cmake#build#RunInstall().
"
" Params:
"     bg : Number
"         whether to run the command in the background
"     wait : Number
"         whether to wait for completion (only for bg == 1)
"
function! cmake#Install(bg, wait) abort
    call cmake#build#RunInstall(a:bg, a:wait)
endfunction

" API function for cmake#console#Open().
"
function! cmake#Open() abort
    call cmake#console#Open(0)
endfunction

" API function for cmake#console#Close().
"
function! cmake#Close() abort
    call cmake#console#Close()
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Other public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get path to CMake source directory of current project, possibly reduced
" relatively to CWD.
"
" Returns:
"     String
"         path to CMake source directory, unescaped (thus it must be first
"         escaped to be used as a command argument)
"
function! cmake#GetSourceDir() abort
    return fnamemodify(cmake#util#FindProjectRoot(), ':.')
endfunction

" Get path to location where the build directory is located, possibly reduced
" relatively to CWD.
"
" Returns:
"     String
"         path to build directory location, unescaped (thus it must be first
"         escaped to be used as a command argument)
"
function! cmake#GetBuildDirLocation() abort
    let l:build_dir_location = join(
            \ [cmake#GetSourceDir(), g:cmake_build_dir_location], '/')
    return fnamemodify(l:build_dir_location, ':.')
endfunction
