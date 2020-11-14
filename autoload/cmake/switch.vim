" ==============================================================================
" Location:    autoload/cmake/switch.vim
" Description: Functions for switching between CMake configurations (Debug,
"              Release, ...)
" ==============================================================================

let s:config = g:cmake_default_config
let s:existing_configs = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate list of existing configurations directories (with a buildsystem).
"
function! cmake#switch#SearchForExistingConfigs() abort
    let l:escaped_build_dir_full_path = fnameescape(
            \ fnamemodify(cmake#switch#GetBuildDir(), ':p'))
    let l:cache_dirs = findfile(
            \ 'CMakeCache.txt', l:escaped_build_dir_full_path . '/**1', -1)
    call map(l:cache_dirs, {_, val -> fnamemodify(val, ':h:t')})
    let s:existing_configs = l:cache_dirs
endfunction

" Get list of existing configurations directories (with a buildsystem).
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
"         stringified list of existing configuration directories
"
function! cmake#switch#GetExistingConfigs(arg_lead, cmd_line, cursor_pos) abort
    if empty(s:existing_configs)
        call cmake#switch#SearchForExistingConfigs()
    endif
    return join(s:existing_configs, "\n")
endfunction

" Set current build configuration.
"
" Params:
"     config : String
"         build configuration
"
function! cmake#switch#SetCurrent(config) abort
    " Set config.
    let s:config = a:config
    " Link compile commands, if requested.
    if g:cmake_link_compile_commands
        let l:command = ['ln', '-sf',
                \ cmake#switch#GetPathToCurrent() . '/compile_commands.json',
                \ cmake#GetSourceDir()
                \ ]
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Get current build configuration.
"
" Returns:
"     String
"         current build configuration
"
function! cmake#switch#GetCurrent() abort
    return s:config
endfunction

" Get path to parent build configuration, possibly reduced relatively to CWD.
"
" Returns:
"     String
"         (unescaped) path to parent build configuration
"
function! cmake#switch#GetBuildDir() abort
    let l:source_dir = cmake#GetSourceDir()

    " It seems impossible to resolve a relative path otherwise.
    exec 'lcd ' . l:source_dir
    let l:build_dir = expand(g:cmake_build_directory, ':p')
    lcd -

    return l:build_dir
endfunction

" Get path to current build configuration, possibly reduced relatively to CWD.
"
" Returns:
"     String
"         (unescaped) path to current build configuration
"
function! cmake#switch#GetPathToCurrent() abort
    " Append configuration name to the build directory.
    return fnamemodify(
            \ join([cmake#switch#GetBuildDir(), cmake#switch#GetCurrent()], '/'),
            \ ':.')
endfunction
