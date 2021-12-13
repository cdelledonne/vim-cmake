" ==============================================================================
" Location:    autoload/cmake/buildsys.vim
" Description: Functions for generating the buildsystem
" ==============================================================================

let s:buildsys = {}
let s:buildsys.cmake_version = 0
let s:buildsys.current_config = ''
let s:buildsys.path_to_current_config = ''
let s:buildsys.configs = []

let s:logger = cmake#logger#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get path to CMake source directory of current project, possibly reduced
" relatively to CWD.
"
" Returns:
"     String
"         path to CMake source directory
"
function! s:GetSourceDir() abort
    return fnamemodify(cmake#util#FindProjectRoot(), ':.')
endfunction

" Get path to location where the build directory is located, possibly reduced
" relatively to CWD.
"
" Returns:
"     String
"         path to build directory location
"
function! s:GetBuildDirLocation() abort
    if g:cmake_build_dir_location ==# '.' || g:cmake_build_dir_location ==# './'
        let l:build_dir_location = s:GetSourceDir()
    else
        let l:build_dir_location = join(
                \ [s:GetSourceDir(), g:cmake_build_dir_location], '/')
        " Re-escape path name after concatenation.
        let l:build_dir_location = fnameescape(l:build_dir_location)
    endif
    return fnamemodify(l:build_dir_location, ':.')
endfunction

" Find CMake variable in list of options.
"
" Params:
"     opts : List
"         list of options
"     variable : String
"         variable to find
"
" Returns:
"     String
"         value of the CMake variable, or an empty string if the variable was
"         not found
"
" Example:
"     to find the variable 'CMAKE_BUILD_TYPE', which would be passed by the user
"     as '-D CMAKE_BUILD_TYPE=<value>', call
"             s:FindVarInOpts(opts, 'CMAKE_BUILD_TYPE')
"
function! s:FindVarInOpts(opts, variable) abort
    if len(a:opts)
        " Search the list of command-line options for an entry matching
        " '-D <variable>=<value>' or '-D <variable>:<type>=<value>' or
        " '-D<variable>=<value>' or '-D<variable>:<type>=<value>'.
        let l:opt = matchstr(a:opts, '\m\C-D\s*' . a:variable)
        " If found, return the value, otherwise return an empty string.
        if len(l:opt)
            return split(l:opt, '=')[1]
        else
            return ''
        endif
    endif
endfunction

" Process build configuration.
"
" Params:
"     opts : List
"         list of options
"
function! s:ProcessBuildConfig(opts) abort
    let l:config = s:buildsys.current_config
    " Check if the first entry of the list of command-line options starts with a
    " letter (and not with a dash), in which case the user will have passed the
    " name of the build configuration as the first option.
    if (len(a:opts) > 0) && (match(a:opts[0], '\m\C^\w') >= 0)
        " Update build config name and remove from list of options.
        let l:config = a:opts[0]
        call s:SetCurrentConfig(l:config)
        call remove(a:opts, 0)
        " Link compile commands, if requested.
        if g:cmake_link_compile_commands
            call s:LinkCompileCommands()
        endif
    endif
    " If the list of command-line options does not contain an explicit value for
    " the 'CMAKE_BUILD_TYPE' variable, add it.
    if s:FindVarInOpts(a:opts, 'CMAKE_BUILD_TYPE') ==# ''
        call add(a:opts, '-D CMAKE_BUILD_TYPE=' . l:config)
    endif
endfunction

" Get list of command-line options from string of arguments.
"
" Params:
"     argstring : String
"         string containing command-line arguments
"
" Returns:
"     List
"         list of unprocessed command-line options
"
" Example:
"     an argument string like the following
"         'Debug -D VAR_A=1 -DVAR_B=0 -Wdev -U VAR_C'
"     results in a list of options like the following
"         ['Debug', '-D VAR_A=1', '-DVAR_B=0', '-Wdev', '-U VAR_C']
"
function! s:ArgStringToOptList(argstring) abort
    let l:opts = []
    for l:arg in split(a:argstring)
        " If list of options is empty, append first argument.
        if len(l:opts) == 0
            call add(l:opts, l:arg)
        " If argument starts with a dash, append it to the list of options.
        elseif match(l:arg, '\m\C^-') >= 0
            call add(l:opts, l:arg)
        " If argument does not start with a dash, it must belong to the last
        " option that was added to the list, thus extend that option.
        else
            let l:opts[-1] = join([l:opts[-1], l:arg])
        endif
    endfor
    return l:opts
endfunction

" Process string of arguments and return parsed options.
"
" Params:
"     argstring : String
"         string containing command-line arguments
"
" Returns:
"     Dictionary
"         opts : List
"             list of options
"         source_dir : String
"             path to source directory
"         build_dir : String
"             path to build directory
"
function! s:ProcessArgString(argstring) abort
    let l:opts = s:ArgStringToOptList(a:argstring)
    call s:ProcessBuildConfig(l:opts)
    " If compile commands are to be exported, and the
    " 'CMAKE_EXPORT_COMPILE_COMMANDS' variable is not set, set it.
    if g:cmake_link_compile_commands
        if s:FindVarInOpts(l:opts, 'CMAKE_EXPORT_COMPILE_COMMANDS') ==# ''
            call add(l:opts, '-D CMAKE_EXPORT_COMPILE_COMMANDS=ON')
        endif
    endif
    " Set source and build directories. Must be done after processing the build
    " configuration so that the current build configuration is up to date before
    " setting the build directory.
    let l:source_dir = s:GetSourceDir()
    let l:build_dir = s:buildsys.path_to_current_config
    " Return dictionary of options.
    let l:optdict = {}
    let l:optdict.opts = l:opts
    let l:optdict.source_dir = l:source_dir
    let l:optdict.build_dir = l:build_dir
    return l:optdict
endfunction

" Refresh list of build configuration directories.
"
function! s:RefreshConfigs() abort
    " Location of the build directory. It must be re-escaped because of the
    " transformation to absolute path.
    let l:escaped_build_dir_location_full_path =
            \ fnameescape(fnamemodify(s:GetBuildDirLocation(), ':p'))
    " List of directories inside of which a CMakeCache file is found.
    let l:cache_dirs = findfile(
            \ 'CMakeCache.txt',
            \ l:escaped_build_dir_location_full_path . '/**1',
            \ -1)
    " Transform paths to just names of directories. These will be the names of
    " existing configuration directories.
    call map(l:cache_dirs, {_, val -> fnamemodify(val, ':h:t')})
    let s:buildsys.configs = l:cache_dirs
endfunction

" Check if build configuration directory exists.
"
" Params:
"     config : String
"         configuration to check
"
" Returns:
"     Number
"         1 if the build configuration exists, 0 otherwise
"
function! s:ConfigExists(config) abort
    return index(s:buildsys.configs, a:config) >= 0
endfunction

" Set current build configuration.
"
" Params:
"     config : String
"         build configuration name
"
function! s:SetCurrentConfig(config) abort
    let s:buildsys.current_config = a:config
    let s:buildsys.path_to_current_config = fnamemodify(
            \ join([s:GetBuildDirLocation(), a:config], '/'), ':.')
endfunction

" Link compile commands from source directory to build directory.
"
function! s:LinkCompileCommands() abort
    let l:target = join(
            \ [s:buildsys.path_to_current_config, 'compile_commands.json'], '/')
    let l:link_dest = s:GetSourceDir()
    let l:command = ['ln', '-sf', l:target, l:link_dest]
    call cmake#command#Run(l:command, 1, 1)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate a buildsystem for the project using CMake.
"
" Params:
"     clean : Number
"         whether to clean before generating
"     argstring : String
"         build configuration and additional CMake options
"
function! s:buildsys.Generate(clean, argstring) abort
    let l:command = [g:cmake_command]
    let l:optdict = s:ProcessArgString(a:argstring)
    " Construct command.
    call extend(l:command, g:cmake_generate_options)
    call extend(l:command, l:optdict.opts)
    if l:self.cmake_version < 313
        call add(l:command, '-H' . l:optdict.source_dir)
        call add(l:command, '-B' . l:optdict.build_dir)
    else
        call add(l:command, '-S ' . l:optdict.source_dir)
        call add(l:command, '-B ' . l:optdict.build_dir)
    endif
    call cmake#console#SetCmdId('generate')
    " Clean project buildsystem, if requested.
    if a:clean
        call l:self.Clean()
    endif
    " Run generate command.
    call cmake#command#Run(l:command, 0, 0)
    " Link compile commands, if requested.
    if g:cmake_link_compile_commands
        call s:LinkCompileCommands()
    endif
endfunction

" Clean buildsystem.
"
function! s:buildsys.Clean() abort
    if isdirectory(l:self.path_to_current_config)
        let l:command = ['rm', '-rf', l:self.path_to_current_config . '/*']
        call cmake#command#Run(l:command, 1, 1)
    endif
    call s:RefreshConfigs()
endfunction

" Set current build configuration after checking that the configuration exists.
"
" Params:
"     config : String
"         build configuration name
"
function! s:buildsys.Switch(config) abort
    " Check that config exists.
    if !s:ConfigExists(a:config)
        call s:logger.Error(
                \ "Build configuration '%s' not found, run ':CMakeGenerate %s'",
                \ a:config, a:config)
        return
    endif
    call s:SetCurrentConfig(a:config)
    " Link compile commands, if requested.
    if g:cmake_link_compile_commands
        call s:LinkCompileCommands()
    endif
endfunction

" Get list of configuration directories (containing a buildsystem).
"
" Returns:
"     List
"         list of existing configuration directories
"
function! s:buildsys.GetConfigs() abort
    return l:self.configs
endfunction

" Get current build configuration.
"
" Returns:
"     String
"         build configuration
"
function! s:buildsys.GetCurrentConfig() abort
    return l:self.current_config
endfunction

" Get path to current build configuration.
"
" Returns:
"     String
"         path to build configuration
"
function! s:buildsys.GetPathToCurrentConfig() abort
    return l:self.path_to_current_config
endfunction

" Get buildsys 'object'.
"
function! cmake#buildsys#Get() abort
    return s:buildsys
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:GetCMakeVersionCb(...) abort
    let l:data = cmake#job#GetCallbackData(a:000)
    if match(l:data, '\m\C^cmake\S* version') == 0
        let l:version_str = split(split(l:data)[2], '\.')
        let l:major = str2nr(l:version_str[0])
        let l:minor = str2nr(l:version_str[1])
        let s:buildsys.cmake_version = l:major * 100 + l:minor
    endif
endfunction

" Get CMake version. The version is stored as MAJOR * 100 + MINOR (e.g., version
" 3.13.3 would result in 313).
let s:command = [g:cmake_command, '--version']
call cmake#command#Run(s:command, 1, 1, function('s:GetCMakeVersionCb'))

call s:SetCurrentConfig(g:cmake_default_config)

call s:RefreshConfigs()

call cmake#console#RegisterCallback(function('s:RefreshConfigs'))
