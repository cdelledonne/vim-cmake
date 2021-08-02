" ==============================================================================
" Location:    autoload/cmake/logger.vim
" Description: Logger
" ==============================================================================

let s:logger = {}

function! s:Log(fmt, arglist) abort
    " Trick to convert list (a:arglist) into arguments for printf().
    let l:PrintfPartial = function('printf', [a:fmt] + a:arglist)
    echomsg '[Vim-CMake] ' . l:PrintfPartial()
endfunction

" Echo an information message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.Info(fmt, ...) abort
    echohl MoreMsg
    call s:Log(a:fmt, a:000)
    echohl None
endfunction

" Echo a warning message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.Warn(fmt, ...) abort
    echohl WarningMsg
    call s:Log(a:fmt, a:000)
    echohl None
endfunction

" Echo an error message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.Error(fmt, ...) abort
    echohl Error
    call s:Log(a:fmt, a:000)
    echohl None
endfunction

" Get logger 'object'
"
function! cmake#logger#Get() abort
    return s:logger
endfunction
