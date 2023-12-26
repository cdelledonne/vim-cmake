" ==============================================================================
" Location:    autoload/cmake/build.vim
" Description: Functions for building a project
" ==============================================================================

let s:build = {}
let s:build.qflist_id = -1

let s:buildsys = cmake#buildsys#Get()
let s:const = cmake#const#Get()
let s:fileapi = cmake#fileapi#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:quickfix = libs#quickfix#Get()
let s:system = libs#system#Get()
let s:terminal = cmake#terminal#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get dictionary of build arguments from command-line string.
"
" Params:
"     args : List
"         command-line arguments, like target and additional build options
"
" Returns:
"     Dictionary
"         CMake build options, target and native options
"
" Example:
"     args = ['--parallel', '4', 'all', '--', 'VERBOSE=1']
"     return = {
"         \ 'cmake_build_options': ['--parallel', '4'],
"         \ 'target': ['--target', 'all'],
"         \ 'native_build_options': ['VERBOSE=1']
"     \ }
"
function! s:GetBuildArgs(args) abort
    let argdict = {}
    let argdict.cmake_build_options = []
    let argdict.target = []
    let argdict.native_build_options = []
    let arglist = deepcopy(a:args)
    " Search arguments for one that matches the name of a target.
    call s:RefreshTargets()
    for target in s:fileapi.GetBuildTargets()
        let match_res = match(arglist, '\m\C^' . target)
        if match_res != -1
            " If found, get target and remove from list of arguments.
            let target = arglist[match_res]
            let argdict.target = ['--target', target]
            call remove(arglist, match_res)
            break
        endif
    endfor
    " Search for command-line native build tool arguments.
    let match_res = match(arglist, '\m\C^--$')
    if match_res != -1
        " Get command-line native build tool arguments and remove from list.
        let argdict.native_build_options = arglist[match_res+1:]
        " Remove from list of other arguments.
        call remove(arglist, match_res, -1)
    endif
    " Get command-line CMake arguments.
    let argdict.cmake_build_options = arglist
    return argdict
endfunction

" Generate quickfix list after running build command.
"
function! s:GenerateQuickfix() abort
    let s:build.qflist_id = s:quickfix.Generate(
        \ s:terminal.GetOutput(), s:build.qflist_id, 'Vim-CMake')
endfunction

" Refresh list of available CMake build targets.
"
function! s:RefreshTargets() abort
    try
        call s:fileapi.Parse(s:buildsys.GetPathToCurrentConfig())
    catch
    endtry
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Build a project using the generated buildsystem.
"
" Params:
"     clean : Boolean
"         whether to clean before building
"     args : List
"         build target and other options
"
function! s:build.Build(clean, args) abort
    call s:logger.LogDebug('Invoked: build.Build(%s, %s)',
            \ a:clean, string(a:args))
    let path_to_current_config = s:buildsys.GetPathToCurrentConfig()
    let build_dir = s:system.Path([path_to_current_config], v:true)
    let command = [g:cmake_command, '--build', build_dir]
    let options = {}
    " Parse additional options.
    let options = s:GetBuildArgs(a:args)
    " Add CMake build options to the command.
    let command += g:cmake_build_options
    let command += options.cmake_build_options
    if a:clean
        let command += ['--clean-first']
    endif
    " Add target to the command, if any was provided.
    let command += options.target
    " Add native build tool options to the command.
    if len(g:cmake_native_build_options) > 0 ||
        \ len(options.native_build_options) > 0
        let command += ['--']
        let command += g:cmake_native_build_options
        let command += options.native_build_options
    endif
    call s:fileapi.UpdateQueries(build_dir)
    " Run build command.
    let run_options = {}
    let run_options.callbacks_succ = [
        \ function('s:GenerateQuickfix'),
        \ function('s:RefreshTargets'),
        \ ]
    let run_options.callbacks_err = [
        \ function('s:GenerateQuickfix'),
        \  function('s:RefreshTargets'),
        \ ]
    let run_options.autocmds_pre = ['CMakeBuildPre']
    let run_options.autocmds_succ = ['CMakeBuildSucceeded']
    let run_options.autocmds_err = ['CMakeBuildFailed']
    call s:terminal.Run(command, 'BUILD', run_options)
endfunction

" Install a project.
"
function! s:build.Install() abort
    call s:logger.LogDebug('Invoked: build.Install()')
    let path_to_current_config = s:buildsys.GetPathToCurrentConfig()
    let build_dir = s:system.Path([path_to_current_config], v:true)
    let command = [g:cmake_command, '--install', build_dir]
    call s:terminal.Run(command, 'INSTALL', {})
endfunction

" Get build 'object'.
"
function! cmake#build#Get() abort
    return s:build
endfunction
