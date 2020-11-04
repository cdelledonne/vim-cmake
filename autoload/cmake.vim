" ==============================================================================
" Location:    autoload/cmake.vim
" Description: API functions and global data for Vim-CMake
" ==============================================================================

let s:plugin_version = '0.4.0'

" Get project root and try to reduce path to be relative to CWD. The path is
" not escaped, thus it must be first escaped to be used as a command argument.
let s:source_dir = fnamemodify(cmake#util#FindProjectRoot(), ':.')

" Print news of new Vim-CMake versions.
call cmake#plugnews#Print(s:plugin_version, {
        \ '0.2.0': 'Vim-CMake has a new feature, run `:help cmake-switch`',
        \ '0.3.0': 'Vim-CMake has a new feature, run `:help cmake-quickfix`',
        \ '0.4.0': 'Vim-CMake has a new config option `g:cmake_generate_options`',
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
    let l:arglist = []
    let l:cmake_build_type_set = 0
    " Get CMake build type from command-line arguments, if present.
    if a:0 > 0
        let l:arglist = split(a:1)
        let [l:build_type, l:cmake_build_type_set] =
                \ cmake#generate#GetBuildType(l:arglist)
        if len(l:build_type)
            call cmake#switch#SetCurrent(l:build_type)
            " Remove build config substring from command-line options if it was
            " passed in the form `:CMakeGenerate <config>`
            if !l:cmake_build_type_set
                call remove(l:arglist, 0)
            endif
        endif
    endif
    " Clean project buildsystem, if requested.
    if a:clean
        call cmake#generate#Clean()
    endif
    " Add CMake options to the command.
    let l:opts = []
    if len(l:arglist)
        let l:opts = l:arglist
    endif
    " Add -DCMAKE_BUILD_TYPE to the CMake options, unless passed by the user.
    if !l:cmake_build_type_set
        let l:opts += ['-DCMAKE_BUILD_TYPE=' . cmake#switch#GetCurrent()]
    endif
    " Call command.
    call cmake#generate#Run(a:bg, a:wait, l:opts)
endfunction

" API function for cmake#generate#Clean().
"
function! cmake#Clean() abort
    call cmake#generate#Clean()
endfunction

" API function for cmake#switch#SetCurrent().
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
    call cmake#switch#SetCurrent(a:1)
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
"         (unescaped) path to CMake source directory
function! cmake#GetSourceDir() abort
    return s:source_dir
endfunction
