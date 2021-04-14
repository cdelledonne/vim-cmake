" ==============================================================================
" Location:    autoload/cmake/generate.vim
" Description: Functions for generating the buildsystem
" ==============================================================================

function! s:GetCMakeVersionCb(...) abort
    let l:data = cmake#job#GetCallbackData(a:000)
    if match(l:data, '\m\C^cmake version') == 0
        let l:version_str = split(split(l:data)[2], '\.')
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

" Find CMake cache variable in list of command-line arguments.
"
" Params:
"     arglist : List
"         list of command-line arguments
"     variable : String
"         variable to find
"
" Returns:
"     String
"         value of the CMake cache variable, or an empty string if the variable
"         was not found
"
" Example:
"     to find the variable 'CMAKE_BUILD_TYPE', which would be passed by the user
"     as '-D CMAKE_BUILD_TYPE=<value>', call
"             s:FindCacheVariable(arglist, 'CMAKE_BUILD_TYPE')
"
function! s:FindCacheVariable(arglist, variable) abort
    if len(a:arglist)
        " Search the list of command-line arguments for an entry matching
        " '-D <variable>=<value>' or '-D <variable>:<type>=<value>' or
        " '-D<variable>=<value>' or '-D<variable>:<type>=<value>'.
        let l:arg = matchstr(a:arglist, '\m\C-D\s*' . a:variable)
        " If found, return the value, otherwise return an empty string.
        if len(l:arg)
            return split(l:arg, '=')[1]
        else
            return ''
        endif
    endif
endfunction

" Process and possibly update the build configuration.
"
" Params:
"     arglist : List
"         list of command-line arguments
"
" Returns:
"     List
"         list of updated command-line arguments
"
function! s:ProcessBuildConfig(arglist) abort
    let l:arglist = a:arglist
    let l:build_config = cmake#switch#GetCurrentConfigName()
    " Check if the first entry of the list of command-line arguments starts with
    " a letter (and not with a dash), in which case the user will have passed
    " the name of the build configuration as the first argument.
    if (len(l:arglist) > 0) && (match(l:arglist[0], '\m\C^\w') >= 0)
        " Update current build configuration and remove build configuration name
        " from the list of arguments.
        let l:build_config = l:arglist[0]
        call cmake#switch#SetCurrentConfigName(l:build_config)
        call remove(l:arglist, 0)
    endif
    " Check if the list of command-line arguments does not contain an explicit
    " value for the 'CMAKE_BUILD_TYPE' cache variable.
    if s:FindCacheVariable(l:arglist, 'CMAKE_BUILD_TYPE') == ''
        " If build configuration does not exist yet, set the 'CMAKE_BUILD_TYPE'
        " cache variable.
        let l:configs = split(cmake#switch#GetExistingConfigs('', '', 0))
        if index(l:configs, l:build_config) == -1
            let l:arglist += ['-D CMAKE_BUILD_TYPE=' . l:build_config]
        endif
    endif
    return l:arglist
endfunction

" Get list of command-line arguments from string of arguments.
"
" Params:
"     argstring : String
"         string containing command-line arguments
"
" Returns:
"     List
"         list of unprocessed command-line arguments
"
" Example:
"     an argument string like the following
"         'Debug -D VAR_A=1 -DVAR_B=0 -Wdev -U VAR_C'
"     results in a list of arguments like the following
"         ['Debug', '-D VAR_A=1', '-DVAR_B=0', '-Wdev', '-U VAR_C']
"
function! s:GetArgList(argstring) abort
    let l:arglist = []
    for l:arg in split(a:argstring)
        " If list is empty, append first argument.
        if len(l:arglist) == 0
            let l:arglist += [l:arg]
        " If argument starts with a dash, append it to the list.
        elseif match(l:arg, '\m\C^-') >= 0
            let l:arglist += [l:arg]
        " If argument does not start with a dash, it must belong to the last
        " argument that was added to the list, thus extend that argument.
        else
            let l:arglist[-1] = join([l:arglist[-1], l:arg])
        endif
    endfor
    return l:arglist
endfunction

" Parse command-line input string and get list of options to pass to CMake.
"
" Params:
"     argstring : String
"         string containing command-line arguments
"
" Returns:
"     List
"         list of parsed command-line arguments
"
function! s:ParseArgs(argstring) abort
    " Get unprocessed list of arguments.
    let l:arglist = s:GetArgList(a:argstring)
    " Process build configuration and get updated list of arguments.
    let l:arglist = s:ProcessBuildConfig(l:arglist)
    " If compile commands are to be exported, and the
    " 'CMAKE_EXPORT_COMPILE_COMMANDS' cache variable is not set, set it.
    if g:cmake_link_compile_commands
        if s:FindCacheVariable(l:arglist, 'CMAKE_EXPORT_COMPILE_COMMANDS') == ''
            let l:arglist += ['-D CMAKE_EXPORT_COMPILE_COMMANDS=ON']
        endif
    endif
    " Finally, return list of arguments obtained from parsed argument string.
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
    let l:argstring = (a:0 > 0 && len(a:1) > 0) ? a:1 : ''
    let l:arglist = s:ParseArgs(l:argstring)
    " Set source and build directories. Must be done after calling s:ParseArgs()
    " so that the current build configuration is up to date before setting the
    " build directory.
    let l:source_dir = fnameescape(cmake#GetSourceDir())
    let l:build_dir = fnameescape(cmake#switch#GetCurrentConfigDir())
    " Add CMake generate options to the command.
    let l:command += g:cmake_generate_options
    let l:command += l:arglist
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
    let l:build_dir = fnameescape(cmake#switch#GetCurrentConfigDir())
    if isdirectory(l:build_dir)
        let l:command = ['rm', '-rf', l:build_dir . '/*']
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction
