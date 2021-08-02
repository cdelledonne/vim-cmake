" ==============================================================================
" Location:    autoload/cmake/build.vim
" Description: Functions for building a project
" ==============================================================================

let s:cmake_targets = []

let s:buildsys = cmake#buildsys#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Internal functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get dictionary of build arguments from command-line string.
"
" Params:
"     argstring : String
"         command-line arguments, like target and additional build options
"
" Returns:
"     Dictionary
"         CMake build options, target and native options
"
" Example:
"     argstring = --jobs 4 all -- VERBOSE=1
"     return = {
"             \ 'cmake_build_options': ['--jobs', '4'],
"             \ 'target': ['--target', 'all'],
"             \ 'native_build_options': ['VERBOSE=1']
"             \ }
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
function! s:GetTargetsCb(...) abort
    let l:data = cmake#job#GetCallbackData(a:000)
    if match(l:data, '\m\C\.\.\.\s') == 0
        let l:target = split(l:data)[1]
        let s:cmake_targets += [l:target]
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Build a project using the generated buildsystem.
"
" Params:
"     clean : Number
"         whether to clean before building
"     argstring : String
"         build target and other options
"
function! cmake#build#Run(clean, argstring) abort
    let l:build_dir = s:buildsys.GetPathToCurrentConfig()
    let l:command = [g:cmake_command, '--build', l:build_dir]
    let l:options = {}
    " Parse additional options.
    let l:options = s:GetBuildArgs(a:argstring)
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
    call cmake#command#Run(l:command, 0, 0)
endfunction

" Install a project.
"
" Params:
"     bg : Number
"         whether to run the command in the background
"     wait : Number
"         whether to wait for completion (only for bg == 1)
"
function! cmake#build#RunInstall(bg, wait) abort
    let l:build_dir = s:buildsys.GetPathToCurrentConfig()
    let l:command = [g:cmake_command, '--install', l:build_dir]
    call cmake#console#SetCmdId('install')
    call cmake#command#Run(l:command, a:bg, a:wait)
endfunction

" Get list of available CMake targets. Used for autocompletion of commands.
"
" Params:
"     arg_lead : String
"         the leading portion of the argument currently being completed
"     cmd_line : String
"         the entire command line
"     cursor_pos : Number
"         the cursor position in the command line (byte index)
"
" Returns:
"     String
"         available targets, one per line
"
function! cmake#build#GetTargets(arg_lead, cmd_line, cursor_pos) abort
    return join(s:cmake_targets, "\n")
endfunction

" Update list of available CMake targets.
"
function! cmake#build#UpdateTargets() abort
    let s:cmake_targets = []
    let l:build_dir = s:buildsys.GetPathToCurrentConfig()
    let l:command = [g:cmake_command,
            \ '--build', l:build_dir,
            \ '--target', 'help'
            \ ]
    call cmake#command#Run(l:command, 1, 1, function('s:GetTargetsCb'))
endfunction
