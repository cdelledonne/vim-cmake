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
    let l:source_dir_full_path = fnamemodify(g:cmake#source_dir, ':p')
    let l:cache_dirs = findfile(
            \ 'CMakeCache.txt', l:source_dir_full_path . '/**1', -1)
    call map(l:cache_dirs, {_, val -> fnamemodify(val, ':h')})
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
                \ s:config . '/compile_commands.json',
                \ g:cmake#source_dir
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
