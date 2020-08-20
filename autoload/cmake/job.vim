" ==============================================================================
" Location:    autoload/cmake/job.vim
" Description: Job and terminal abstraction layer for Vim and Neovim
" ==============================================================================

" Dictionary of ('job': 'stdout_cb') pairs.
let s:job_callbacks = {}

function! s:NeovimStdoutCallback(job_id, data, event) abort
    if has_key(s:job_callbacks, a:job_id) &&
            \(s:job_callbacks[a:job_id] isnot# v:null)
        call s:job_callbacks[a:job_id](join(a:data))
    endif
endfunction

function! s:VimStdoutCallback(channel, message) abort
    if has_key(s:job_callbacks, a:channel) &&
            \(s:job_callbacks[a:channel] isnot# v:null)
        call s:job_callbacks[a:channel](a:message)
    endif
endfunction

function! s:NeovimExitCallback(job_id, data, event) abort
    if has_key(s:job_callbacks, a:job_id)
        call remove(s:job_callbacks, a:job_id)
    endif
endfunction

function! s:VimExitCallback(channel, message) abort
    if has_key(s:job_callbacks, a:channel)
        call remove(s:job_callbacks, a:channel)
    endif
endfunction

" Start CMake console terminal.
"
" Params:
" - command    command to run in the terminal
" - stdout_cb  stdout callback (must take one argument, the stdout string)
"
" Returns:
" terminal id
"
function! cmake#job#TermStart(command, stdout_cb) abort
    if has('nvim')
        let l:term = termopen(a:command, {
                \ 'on_stdout': function('s:NeovimStdoutCallback'),
                \ 'on_exit': function('s:NeovimExitCallback'),
                \ })
        " Neovim's callbacks are passed the job's ID.
        let s:job_callbacks[l:term] = a:stdout_cb
    else
        let l:term = term_start(a:command, {
                \ 'out_cb': function('s:VimStdoutCallback'),
                \ 'exit_cb': function('s:VimExitCallback'),
                \ 'curwin': 1,
                \ })
        " Vim's callbacks are passed the job's channel.
        let l:chan_id = job_getchannel(term_getjob(l:term))
        let s:job_callbacks[l:chan_id] = a:stdout_cb
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
" - input  input string to send to terminal's stdin
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
" - command    command to run
" - stdout_cb  stdout callback (must take one argument, the stdout string)
"
" Returns:
" job id
"
function! cmake#job#JobStart(command, stdout_cb) abort
    if has('nvim')
        let l:job = jobstart(a:command, {
                \ 'on_stdout': function('s:NeovimStdoutCallback'),
                \ 'on_exit': function('s:NeovimExitCallback'),
                \ })
        " Neovim's callbacks are passed the job's ID.
        let s:job_callbacks[l:job] = a:stdout_cb
    else
        let l:job = job_start(
                \ join([&shell, &shellcmdflag, '"' . a:command . '"']), {
                \ 'out_cb': function('s:VimStdoutCallback'),
                \ 'exit_cb': function('s:VimExitCallback'),
                \ })
        " Vim's callbacks are passed the job's channel.
        let l:chan_id = job_getchannel(l:job)
        let s:job_callbacks[l:chan_id] = a:stdout_cb
    endif
    return l:job
endfunction

" Wait for completion of a job.
"
" Params:
" - job_id  job id
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
