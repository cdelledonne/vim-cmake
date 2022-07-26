" ==============================================================================
" Location:    autoload/cmake/statusline.vim
" Description: Functions for handling  statusline information
" ==============================================================================

let s:statusline = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Force a refresh of the statusline/airline.
"
function! s:statusline.Refresh() abort
    if exists('g:loaded_airline') && g:loaded_airline
        execute 'AirlineRefresh!'
    else
        execute 'redrawstatus!'
    endif
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
    if a:active
        return cmake#GetInfo().config
    else
        return '[' . cmake#GetInfo().config . ']'
    endif
endfunction

" Get command info string for statusline/airline.
"
" Returns:
"     String
"         statusline command info (command currently running)
"
function! cmake#statusline#GetCmdInfo() abort
    if len(cmake#GetInfo().status) > 0
        return cmake#GetInfo().status
    else
        return ' '
    endif
endfunction

" Get statusline 'object'.
"
function! cmake#statusline#Get() abort
    return s:statusline
endfunction
