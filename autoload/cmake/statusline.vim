" ==============================================================================
" Location:    autoload/cmake/statusline.vim
" Description: Functions for handling  statusline information
" ==============================================================================

let s:statusline_cmd_info = ''
let s:statusline_build_info = ''

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! cmake#statusline#Airline(...) abort
    if &filetype is# 'vimcmake'
        let w:airline_section_a = 'CMake'
        let w:airline_section_b = '%{cmake#statusline#GetBuildInfo(1)}'
        let w:airline_section_c = '%{cmake#statusline#GetCmdInfo(1)}'
        let w:airline_section_x = ''
        let w:airline_section_y = ''
    endif
endfunction

function! cmake#statusline#AirlineInactive(...) abort
    if getbufvar(a:2.bufnr, '&filetype') is# 'vimcmake'
        call setwinvar(a:2.winnr, 'airline_section_c',
                \ '[CMake] %{cmake#statusline#GetCmdInfo(0)}')
    endif
endfunction

" Set build info string for statusline/airline.
"
" Params:
" - build_info  string for statusline build info
"
function! cmake#statusline#SetBuildInfo(build_info) abort
    let s:statusline_build_info = a:build_info
endfunction

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
    if len(s:statusline_build_info)
        if a:active
            return s:statusline_build_info
        else
            return '[' . s:statusline_build_info . ']'
        endif
    else
        return ''
    endif
endfunction

" Get command info string for statusline/airline.
"
" Params:
" - active  whether called for the statusline of an active window
"
" Returns:
" string containing statusline command info (command currently running)
"
function! cmake#statusline#GetCmdInfo(active) abort
    if len(s:statusline_cmd_info)
        if a:active
            return s:statusline_cmd_info
        else
            return '[' . s:statusline_cmd_info . ']'
        endif
    else
        return ' '
    endif
endfunction

