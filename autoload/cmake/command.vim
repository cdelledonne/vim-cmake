" ==============================================================================
" Location:    autoload/cmake/command.vim
" Description: Functions for executing CMake commands
" ==============================================================================

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Run arbitrary command in a non-interactive terminal or in the background.
"
" Params:
"     command : List
"         the command to be run, can be a list of command and arguments
"     bg : Number
"         whether to run the command in the background
"     wait : Number
"         for background commands, whether to wait for completion
"     a:1 : Funcref
"         (optional) stdout callback, ignored for non-background commands
"
function! cmake#command#Run(command, bg, wait, ...) abort
    " Note: Funcref variable names must start with a capital.
    let l:StdoutCb = (a:0 > 0) ? a:1 : v:null
    if !a:bg
        " Open Vim-CMake console window with a fresh buffer.
        call cmake#console#Open(0)
        " Run command (send input to terminal buffer).
        call cmake#job#TermSend(join(a:command))
        " Jump to Vim-CMake window if requested.
        if g:cmake_jump
            call cmake#console#Focus()
        endif
    else
        " Run background command and set callback.
        let l:job_id = cmake#job#JobStart(join(a:command), l:StdoutCb)
        if a:wait
            call cmake#job#JobWait(l:job_id)
        endif
    endif
endfunction

" Stop command currently running in the CMake console.
"
function! cmake#command#Stop() abort
    try
        call cmake#job#TermSend("\x03")
    catch /.*/
    endtry
endfunction
