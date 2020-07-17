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
" - cmd_info  string for statusline command info
"
function! cmake#statusline#SetCmdInfo(cmd_info) abort
    let s:statusline_cmd_info = a:cmd_info
endfunction

" Get build info string for statusline/airline.
"
" Params:
" - active  whether called for the statusline of an active window
"
" Returns:
" string containing statusline build info
"
function! cmake#statusline#GetBuildInfo(active) abort
    if a:active
        return cmake#switch#GetCurrent()
    else
        return '[' . cmake#switch#GetCurrent() . ']'
    endif
endfunction

" Get command info string for statusline/airline.
"
" Returns:
" string containing statusline command info (command currently running)
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
