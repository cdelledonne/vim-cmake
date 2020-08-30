" ==============================================================================
" Location:    autoload/cmake/build.vim
" Description: Functions for building a project
" ==============================================================================

let s:cmake_targets = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Internal functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get dictionary of build arguments from command-line string.
"
" Params:
" - argstring  string containing command-line arguments, like target and
"              additional CMake build options
"
" Returns:
" dictionary containing CMake build options, target and native options
"
" Example:
" argstring = --jobs 4 all -- VERBOSE=1
" return = {
"         \ 'cmake_build_options': ['--jobs', '4'],
"         \ 'target': ['--target', 'all'],
"         \ 'native_build_options': ['VERBOSE=1']
"         \ }
"
function! s:GetBuildArgs(argstring) abort
    let l:argdict = {}
    let l:arglist = split(a:argstring)
    call cmake#build#GetTargets('', '', 0)
    " Search arguments for one that matches the name of a target.
    for l:t in s:cmake_targets
        let l:match_res = match(l:arglist, '\m\C^' . l:t)
        if l:match_res != -1
            " If found, get target and remove from list of arguments.
            let l:target =  l:arglist[l:match_res]
            let l:argdict['target'] = ['--target', l:target]
            call remove(l:arglist, l:match_res)
            break
        endif
    endfor
    " Search for command-line native build tool arguments.
    let l:match_res = match(l:arglist, '\m\C^--$')
    if l:match_res != -1
        " Get command-line native build tool arguments and remove from list.
        let l:argdict['native_build_options'] = l:arglist[l:match_res+1:]
        " Remove from list of other arguments.
        call remove(l:arglist, l:match_res, -1)
    endif
    " Get command-line CMake arguments.
    let l:argdict['cmake_build_options'] = l:arglist
    return l:argdict
endfunction

" Callback for cmake#build#GetTargets().
"
function! s:GetTargetsCb(data) abort
    if match(a:data, '\m\C\.\.\.\s') == 0
        let l:target = split(a:data)[1]
        let s:cmake_targets += [l:target]
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Build a project using the generated buildsystem.
"
" Params:
" - bg         whether to run the command in the background
" - wait       whether to wait for completion (only for bg == 1)
" - clean      whether to clean before building
" - [options]  optional string containing target and other options
"
function! cmake#build#Run(bg, wait, clean, ...) abort
    let l:command = [g:cmake_command, '--build', cmake#switch#GetCurrent()]
    let l:options = {}
    " Parse additional options.
    if a:0 > 0 && len(a:1) > 0
        let l:options = s:GetBuildArgs(a:1)
    endif
    " Add CMake build options to the command.
    let l:command += g:cmake_build_options
    let l:command += get(l:options, 'cmake_build_options', [])
    if a:clean
        let l:command += ['--clean-first']
    endif
    " Add target to the command, if any was provided.
    let l:command += get(l:options, 'target', [])
    " Add native build tool options to the command.
    if len(g:cmake_native_build_options) ||
            \ len(get(l:options, 'native_build_options', []))
        let l:command += ['--']
        let l:command += g:cmake_native_build_options
        let l:command += get(l:options, 'native_build_options', [])
    endif
    " Run build command.
    call cmake#console#SetCmdId('build')
    call cmake#command#Run(l:command, a:bg, a:wait)
endfunction

" Install a project.
"
" Params:
" - bg         whether to run the command in the background
" - wait       whether to wait for completion (only for bg == 1)
"
function! cmake#build#RunInstall(bg, wait) abort
    let l:command = [g:cmake_command, '--install', cmake#switch#GetCurrent()]
    call cmake#console#SetCmdId('install')
    call cmake#command#Run(l:command, a:bg, a:wait)
endfunction

" Get list of available CMake targets. Used for autocompletion of commands.
"
" Params:
" - arg_lead    the leading portion of the argument currently being completed
" - cmd_line    the entire command line
" - cursor_pos  the cursor position in it (byte index)
"
" Returns:
" string of available targets, one per line
"
function! cmake#build#GetTargets(arg_lead, cmd_line, cursor_pos) abort
    return join(s:cmake_targets, "\n")
endfunction

" Update list of available CMake targets.
"
function! cmake#build#UpdateTargets() abort
    let s:cmake_targets = []
    let l:command = [g:cmake_command,
            \ '--build', cmake#switch#GetCurrent(),
            \ '--target', 'help'
            \ ]
    call cmake#command#Run(l:command, 1, 1, function('s:GetTargetsCb'))
endfunction
