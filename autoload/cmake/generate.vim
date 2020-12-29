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

" Find CMake configuration variable in list of command-line arguments.
"
" Params:
"     arglist : List
"         list of command-line arguments
"     variable : String
"         variable to find
"
" Returns:
"     String
"         value of the CMake configuration variable, or an empty string if the
"         variable was not found
"
" Example:
"     to find the variable 'CMAKE_BUILD_TYPE', which would be passed by the user
"     as '-DCMAKE_BUILD_TYPE=<value>', call
"             s:FindVariable(arglist, 'CMAKE_BUILD_TYPE')
"
function! s:FindVariable(arglist, variable) abort
    if len(a:arglist)
        " Search the list of command-line arguments for an entry matching
        " '-D<variable>=<value>' or '-D<variable>:<type>=<value>'.
        let l:arg = matchstr(a:arglist, '\m\C-D' . a:variable)
        " If found, return the value, otherwise return an empty string.
        if len(l:arg)
            return split(l:arg, '=')[1]
        else
            return ''
        endif
    endif
endfunction

" Get CMake build configuration value from command-line arguments.
"
" Params:
"     arglist : List
"         list of command-line arguments
"
" Returns:
"     List
"         list, whose first value is the build configuration, and the second
"         value is a flag that is set when the build configuration appears in
"         the arguments as '-DCMAKE_BUILD_TYPE=<config>'
"
function! s:GetBuildType(arglist) abort
    if len(a:arglist)
        " Check if the first entry of the list of command-line arguments starts
        " with a letter (and for instance not with a dash), in which case the
        " user will have passed the name of the build configuration as the first
        " argument (but the variable 'CMAKE_BUILD_TYPE' will have not been set
        " explicitly by the user).
        if match(a:arglist[0], '\m\C^\w') >= 0
            return [a:arglist[0], 0]
        else
            " Search the list of command-line arguments for the
            " 'CMAKE_BUILD_TYPE' variable.
            let l:build_type = s:FindVariable(a:arglist, 'CMAKE_BUILD_TYPE')
            if len(l:build_type)
                return [l:build_type, 1]
            else
                return ['', 0]
            endif
        endif
    else
        return ['', 0]
    endif
endfunction

" Generate list of filtered command-line arguments.
"
" Params:
"     argstring : String
"         string containing command-line arguments
"
" Returns:
"     List
"         list of command-line arguments
"
function! s:GetGenerateArgs(argstring) abort
    let l:arglist = split(a:argstring)
    let l:cmake_build_type_set = 0
    " Get CMake build type from command-line arguments, if present.
    let [l:build_type, l:cmake_build_type_set] = s:GetBuildType(l:arglist)
    if len(l:build_type)
        call cmake#switch#SetCurrent(l:build_type)
        " Remove build config substring from command-line options if it was
        " passed in the form `:CMakeGenerate <config>`
        if !l:cmake_build_type_set
            call remove(l:arglist, 0)
        endif
    endif
    " Add '-DCMAKE_BUILD_TYPE=<config>' to the CMake options, unless explicitly
    " passed by the user.
    if !l:cmake_build_type_set
        let l:arglist += ['-DCMAKE_BUILD_TYPE=' . cmake#switch#GetCurrent()]
    endif
    " Export compile commands if requested.
    if g:cmake_link_compile_commands
        let l:cmake_export_compile_commands = s:FindVariable(l:arglist,
                \ 'CMAKE_EXPORT_COMPILE_COMMANDS')
        if !len(l:cmake_export_compile_commands)
            let l:arglist += ['-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
        endif
    endif
    return l:arglist
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate a buildsystem for the project using CMake.
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
function! cmake#generate#Run(bg, wait, clean, ...) abort
    let l:command = [g:cmake_command]
    let l:options = []
    " Parse and add additional options.
    if a:0 > 0 && len(a:1) > 0
        let l:options = s:GetGenerateArgs(a:1)
    else
        let l:options = s:GetGenerateArgs('')
    endif
    " Set source and build directories. Must be done after calling
    " s:GetGenerateArgs() so that the current build configuration is up to date
    " before setting the build directory.
    let l:source_dir = fnameescape(cmake#GetSourceDir())
    let l:build_dir = fnameescape(cmake#switch#GetPathToCurrent())
    " Add CMake generate options to the command.
    let l:command += g:cmake_generate_options
    let l:command += l:options
    " Construct command based on CMake version.
    if s:cmake_version < 313
        let l:command += ['-H' . l:source_dir, '-B' . l:build_dir]
    else
        let l:command += ['-S', l:source_dir, '-B', l:build_dir]
    endif
    call cmake#console#SetCmdId('generate')
    " Clean project buildsystem, if requested.
    if a:clean
        call cmake#generate#Clean()
    endif
    " Run generate command.
    call cmake#command#Run(l:command, a:bg, a:wait)
    if g:cmake_link_compile_commands
        " Link compile commands.
        let l:command = ['ln', '-sf',
                \ l:build_dir . '/compile_commands.json',
                \ l:source_dir
                \ ]
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Clean buildsystem (CMake files).
"
function! cmake#generate#Clean() abort
    let l:build_dir = fnameescape(cmake#switch#GetPathToCurrent())
    if isdirectory(l:build_dir)
        let l:command = ['rm', '-rf', l:build_dir . '/*']
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction
