" ==============================================================================
" Location:    autoload/cmake/switch.vim
" Description: Functions for switching between CMake configurations (Debug,
"              Release, ...)
" ==============================================================================

let s:current_config_name = g:cmake_default_config
let s:current_config_dir = fnamemodify(
        \ join([cmake#GetBuildDirLocation(), s:current_config_name], '/'), ':.')
let s:existing_config_dirs = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate list of existing configurations directories (with a buildsystem).
"
function! cmake#switch#SearchForExistingConfigs() abort
    " Location of the build directory, escaped.
    let l:escaped_build_dir_location_full_path =
            \ fnameescape(fnamemodify(cmake#GetBuildDirLocation(), ':p'))
    " List of directories inside of which a CMakeCache file is found.
    let l:cache_dirs = findfile(
            \ 'CMakeCache.txt',
            \ l:escaped_build_dir_location_full_path . '/**1',
            \ -1)
    " Transform paths to just names of directories. These will be the names of
    " existing configuration directories.
    call map(l:cache_dirs, {_, val -> fnamemodify(val, ':h:t')})
    let s:existing_config_dirs = l:cache_dirs
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
    if empty(s:existing_config_dirs)
        call cmake#switch#SearchForExistingConfigs()
    endif
    return join(s:existing_config_dirs, "\n")
endfunction

" Set current build configuration.
"
" Params:
"     name : String
"         build configuration name
"
function! cmake#switch#SetCurrentConfigName(name) abort
    " Set config.
    let s:current_config_name = a:name
    let s:current_config_dir = fnamemodify(
            \ join([cmake#GetBuildDirLocation(), a:name], '/'), ':.')
    " Link compile commands, if requested.
    if g:cmake_link_compile_commands
        let l:command = ['ln', '-sf',
                \ fnameescape(s:current_config_dir . '/compile_commands.json'),
                \ fnameescape(cmake#GetSourceDir())
                \ ]
        call cmake#command#Run(l:command, 1, 1)
    endif
endfunction

" Get current build configuration name.
"
" Returns:
"     String
"         build configuration name
"
function! cmake#switch#GetCurrentConfigName() abort
    return s:current_config_name
endfunction

" Get current build configuration dir.
"
" Returns:
"     String
"         build configuration dir
"
function! cmake#switch#GetCurrentConfigDir() abort
    return s:current_config_dir
endfunction
