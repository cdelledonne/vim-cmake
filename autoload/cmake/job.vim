" ==============================================================================
" Location:    autoload/cmake/job.vim
" Description: Job and terminal abstraction layer for Vim and Neovim
" ==============================================================================

" Start CMake console terminal.
"
" Params:
"     command : String
"         command to run in the terminal
"     stdout_cb : Funcref
"         stdout callback (must take one argument, the stdout string)
"
" Returns:
"     Number
"         terminal id
"
function! cmake#job#TermStart(command, stdout_cb) abort
    let l:options = {}
    if has('nvim')
        if a:stdout_cb isnot# v:null
            let l:options['on_stdout'] = a:stdout_cb
        endif
        let l:term = termopen(a:command, l:options)
    else
        let l:options['curwin'] = 1
        if a:stdout_cb isnot# v:null
            let l:options['out_cb'] = a:stdout_cb
        endif
        let l:term = term_start(a:command, l:options)
    endif
    " Set up autocmd to stop terminal job before exiting Vim/Neovim. Older
    " versions of Vim/Neovim do not have 'ExitPre', in which case we use
    " 'VimLeavePre'. Though, calling TermStop() on 'VimLeavePre' in Vim seems
    " to be to late and results in an error (E947), in which case one should
    " quit with e.g. :qa!.
    augroup cmake
        if exists('##ExitPre')
            autocmd ExitPre * call cmake#job#TermStop()
        else
            autocmd VimLeavePre * call cmake#job#TermStop()
        endif
    augroup END
    return l:term
endfunction

" Send input to terminal buffer.
"
" Params:
"     input : String
"         input string to send to terminal's stdin
"
function! cmake#job#TermSend(input) abort
    if has('nvim')
        call chansend(cmake#console#GetID(), [a:input, ''])
    else
        " For Vim, must go back into Terminal-Job mode for the command's
        " output to be appended to the buffer.
        if mode() !=# 't'
            execute 'normal! i'
        endif
        call term_sendkeys(cmake#console#GetID(), a:input . "\<CR>")
    endif
endfunction

" Stop CMake console terminal.
"
function! cmake#job#TermStop() abort
    try
        if has('nvim')
            let l:job_id = cmake#console#GetID()
            call jobstop(l:job_id)
        else
            let l:job_id = term_getjob(cmake#console#GetID())
            call job_stop(l:job_id)
        endif
        call cmake#job#JobWait(l:job_id)
    catch /.*/
    endtry
endfunction

" Start arbitrary background job.
"
" Params:
"     command : String
"         command to run
"     stdout_cb : Funcref
"         stdout callback, which should take a variable number of arguments,
"         and from which cmake#job#GetCallbackData(a:000) can be called to
"         retrieve the stdout string
"
" Returns:
"     Number (Neovim) or String (Vim)
"         job id (Neovim) or job handle (Vim)
"
function! cmake#job#JobStart(command, stdout_cb) abort
    let l:options = {}
    if has('nvim')
        if a:stdout_cb isnot# v:null
            let l:options['on_stdout'] = a:stdout_cb
        endif
        let l:job = jobstart(a:command, l:options)
    else
        if a:stdout_cb isnot# v:null
            let l:options['out_cb'] = a:stdout_cb
        endif
        let l:vim_command = join([&shell, &shellcmdflag, '"' . a:command . '"'])
        let l:job = job_start(l:vim_command, l:options)
    endif
    return l:job
endfunction

" Wait for completion of a job.
"
" Params:
"     job_id : Number
"         job id
"
function! cmake#job#JobWait(job_id) abort
    if has('nvim')
        call jobwait([a:job_id])
    else
        while job_status(a:job_id) ==# 'run'
            execute 'sleep 5m'
        endwhile
    endif
endfunction

" Get stdout data from a job callback.
"
" Params:
"     cb_arglist : List
"         variable-size list of arguments as passed to the callback, which
"         will differ between Neovim and Vim
"
" Returns:
"     String
"         stdout data (string)
"
function! cmake#job#GetCallbackData(cb_arglist) abort
    if has('nvim')
        return join(a:cb_arglist[1])
    else
        return a:cb_arglist[1]
    endif
endfunction
