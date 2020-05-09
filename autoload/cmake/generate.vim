" ==============================================================================
" Location:    autoload/cmake/generate.vim
" Description: Functions for generating the buildsystem
" ==============================================================================

function! s:GetCMakeVersionCb(data) abort
    if match(a:data, '\m\C^cmake version') == 0
        let l:version_str = split(split(a:data)[2], '\.')
        let l:major = str2nr(l:version_str[0])
        let l:minor = str2nr(l:version_str[1])
        let s:cmake_version = l:major * 100 + l:minor
    endif
endfunction

" Get CMake version. The version is stored in s:cmake_version after the
" invocation of s:get_cmake_version_callback as MAJOR * 100 + MINOR (e.g.,
" version 3.13.3 would result in 313).
let s:command = [g:cmake_command, '--version']
call cmake#command#Run(s:command, 1, 1, function('s:GetCMakeVersionCb'))

" Get project root and try to reduce path to be relative to CWD.
let s:cmake_source_dir = fnamemodify(cmake#util#FindProjectRoot(), ':.')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate a buildsystem for the project using CMake.
"
" Params:
" - bg         whether to run the command in the background
" - wait       whether to wait for completion (only for bg == 1)
" - [options]  optional parameter to specify CMake options
"
function! cmake#generate#Run(bg, wait, ...) abort
    let l:command = [g:cmake_command]
    let l:build_dir = cmake#build#GetBuildDir()
    if a:0 > 0
        " Add CMake build options to the command.
        let l:command += [a:1]
    endif
    " Construct command based on CMake version.
    if s:cmake_version < 313
        let l:command += ['-H' . s:cmake_source_dir, '-B' . l:build_dir]
    else
        let l:command += ['-S', s:cmake_source_dir, '-B', l:build_dir]
    endif
    call cmake#statusline#SetCmdInfo('Generating buildsystem...')
    call cmake#command#Run(l:command, a:bg, a:wait)
    if g:cmake_link_compile_commands
        " Link compile commands.
        let l:command = ['ln', '-sf',
                \ l:build_dir . '/compile_commands.json',
                \ s:cmake_source_dir
                \ ]
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Clean buildsystem (CMake files).
"
function! cmake#generate#Clean() abort
    let l:build_dir = cmake#build#GetBuildDir()
    if isdirectory(l:build_dir)
        let l:command = ['rm', '-rf', l:build_dir . '/*']
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Get CMAKE_BUILD_TYPE value from command-line arguments.
"
" Params:
" - args  command-line arguments string
"
" Returns:
" value of CMAKE_BUILD_TYPE
"
function! cmake#generate#GetBuildType(args) abort
    let l:build_type_arg = matchstr(split(a:args), '\m\CCMAKE_BUILD_TYPE')
    if len(l:build_type_arg)
        return split(l:build_type_arg, '=')[1]
    else
        return ''
    endif
endfunction
