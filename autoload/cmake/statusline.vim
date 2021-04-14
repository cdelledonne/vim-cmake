" ==============================================================================
" Location:    autoload/cmake/statusline.vim
" Description: Functions for handling  statusline information
" ==============================================================================

let s:statusline_cmd_info = ''

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Set command info string for statusline/airline.
"
" Params:
"     cmd_info : String
"         statusline command info
"
function! cmake#statusline#SetCmdInfo(cmd_info) abort
    let s:statusline_cmd_info = a:cmd_info
endfunction

" Get build info string for statusline/airline.
"
" Params:
"     active : Number
"         whether called for the statusline of an active window
"
" Returns:
"     String
"         statusline build info
"
function! cmake#statusline#GetBuildInfo(active) abort
    let l:config_name = cmake#switch#GetCurrentConfigName()
    if a:active
        return l:config_name
    else
        return '[' . l:config_name . ']'
    endif
endfunction

" Get command info string for statusline/airline.
"
" Returns:
"     String
"         statusline command info (command currently running)
"
function! cmake#statusline#GetCmdInfo() abort
    if len(s:statusline_cmd_info)
        return s:statusline_cmd_info
    else
        return ' '
    endif
endfunction

" Force a refresh of the statusline/airline.
"
function! cmake#statusline#Refresh() abort
    if exists('g:loaded_airline') && g:loaded_airline
        execute 'AirlineRefresh!'
    else
        execute 'redrawstatus!'
    endif
endfunction
