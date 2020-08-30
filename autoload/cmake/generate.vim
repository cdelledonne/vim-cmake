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

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate a buildsystem for the project using CMake.
"
" Params:
" - bg       whether to run the command in the background
" - wait     whether to wait for completion (only for bg == 1)
" - options  list of CMake options
"
function! cmake#generate#Run(bg, wait, options) abort
    let l:command = [g:cmake_command]
    let l:build_dir = cmake#switch#GetCurrent()
    " Add CMake build options to the command.
    let l:command += a:options
    " Construct command based on CMake version.
    if s:cmake_version < 313
        let l:command += ['-H' . g:cmake#source_dir, '-B' . l:build_dir]
    else
        let l:command += ['-S', g:cmake#source_dir, '-B', l:build_dir]
    endif
    call cmake#console#SetCmdId('generate')
    call cmake#command#Run(l:command, a:bg, a:wait)
    if g:cmake_link_compile_commands
        " Link compile commands.
        let l:command = ['ln', '-sf',
                \ l:build_dir . '/compile_commands.json',
                \ g:cmake#source_dir
                \ ]
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Clean buildsystem (CMake files).
"
function! cmake#generate#Clean() abort
    let l:build_dir = cmake#switch#GetCurrent()
    if isdirectory(l:build_dir)
        let l:command = ['rm', '-rf', l:build_dir . '/*']
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Get CMake build configuration value from command-line arguments.
"
" Params:
" - arglist  list of command-line arguments
"
" Returns:
" list, whose first value is the build configuration, and the second value is a
" flag that is set when the build configuration appears in the arguments as
" '-DCMAKE_BUILD_TYPE=<config>'
"
function! cmake#generate#GetBuildType(arglist) abort
    if len(a:arglist)
        if match(a:arglist[0], '\m\C^\w') >= 0
            return [a:arglist[0], 0]
        else
            let l:build_type_arg = matchstr(a:arglist, '\m\CCMAKE_BUILD_TYPE')
            if len(l:build_type_arg)
                return [split(l:build_type_arg, '=')[1], 1]
            else
                return ['', 0]
            endif
        endif
    endif
endfunction
