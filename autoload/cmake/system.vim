" ==============================================================================
" Location:    autoload/cmake/system.vim
" Description: System abstraction layer
" ==============================================================================

let s:system = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate escaped path string from list of components.
"
" Params:
"     components : List
"         list of path components (strings)
"     relative : Boolean
"         whether to have the path relative to the current directory or absolute
"
" Returns:
"     String
"         escaped path string with appropriate path separators
"
function! s:system.Path(components, relative) abort
    call assert_notequal(len(a:components), 0)
    " Join path components.
    let l:separator = has('win32') ? '\' : '/'
    let l:path = join(a:components, l:separator)
    let l:path = simplify(l:path)
    " Reduce to relative path or make absolute.
    if a:relative
        let l:path = fnamemodify(l:path, ':.')
    else
        let l:path = fnamemodify(l:path, ':p')
    endif
    " Simplify and escape path.
    let l:path = simplify(l:path)
    let l:path = fnameescape(l:path)
    return l:path
endfunction

" Create symbolic link.
"
" Params:
"     target : String
"         ...
"     link_name : String
"         ...
"     wait : Boolean
"         whether to wait for completion
"
function! s:system.Link(target, link_name, wait) abort
    if has('win32')
        let l:command = ['mklink', a:link_name, a:target]
    else
        let l:command = ['ln', '-sf', a:target, a:link_name]
    endif
    return l:self.JobRun(l:command, a:wait, v:null, v:null, {}, v:false)
endfunction

" Run arbitrary job in the background.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"     wait : Boolean
"         whether to wait for completion
"     stdout_cb : Funcref
"         stdout callback (can be v:null), which should take a variable number
"         of arguments, and from which s:system.ExtractStdoutCallbackData(a:000)
"         can be called to retrieve the stdout string
"     exit_cb : Funcref
"         exit callback (can be v:null), which should take a variable number of
"         arguments, and from which s:system.ExtractExitCallbackData(a:000) can
"         be called to retrieve the exit code
"     env : Dict
"         dictionary of environment variables to pass to the job
"     pty : Boolean
"         whether to allocate a pseudo terminal for the job
"
" Return:
"     Number
"         job id
"
function! s:system.JobRun(command, wait, stdout_cb, exit_cb, env, pty) abort
    " Run background job and set callback.
    let l:options = {'env': a:env, 'pty': a:pty}
    if has('nvim')
        if a:stdout_cb isnot# v:null
            let l:options['on_stdout'] = a:stdout_cb
        endif
        if a:exit_cb isnot# v:null
            let l:options['on_exit'] = a:exit_cb
        endif
        let l:job_id = jobstart(a:command, l:options)
    else
        if a:stdout_cb isnot# v:null
            let l:options['out_cb'] = a:stdout_cb
        endif
        if a:exit_cb isnot# v:null
            let l:options['exit_cb'] = a:exit_cb
        endif
        let l:job_id = job_start(a:command, l:options)
    endif
    " Wait for job to complete, if requested.
    if a:wait
        call l:self.JobWait(l:job_id)
    endif
    return l:job_id
endfunction

" Wait for job to complete.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.JobWait(job_id) abort
    if has('nvim')
        call jobwait([a:job_id])
    else
        while job_status(a:job_id) ==# 'run'
            execute 'sleep 5m'
        endwhile
    endif
endfunction

" Wait for job's channel to be closed.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.ChannelWait(job_id) abort
    " Only makes sense in Vim currently.
    if !has('nvim')
        let l:chan_id = job_getchannel(a:job_id)
        while ch_status(l:chan_id, {'part': 'out'}) !=# 'closed'
            execute 'sleep 5m'
        endwhile
    endif
endfunction

" Stop job.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.JobStop(job_id) abort
    try
        if has('nvim')
            call jobstop(a:job_id)
        else
            call job_stop(a:job_id)
        endif
    catch /.*/
    endtry
endfunction

" Extract data from a job's stdout callback.
"
" Params:
"     cb_arglist : List
"         variable-size list of arguments as passed to the callback, which will
"         differ between Neovim and Vim
"
" Returns:
"     List
"         stdout data, as a list of strings
"
function! s:system.ExtractStdoutCallbackData(cb_arglist) abort
    let l:data = a:cb_arglist[1]
    if has('nvim')
        " For Neovim, l:data is a list, where the first and the last element may
        " be empty strings, which we remove. We also remove all the CR
        " characters, which are returned when a pseudo terminal is allocated for
        " the job.
        if len(l:data) && l:data[0] ==# ''
            call remove(l:data, 0)
        endif
        if len(l:data) && l:data[-1] ==# ''
            call remove(l:data, -1)
        endif
        call map(l:data, {_, val -> substitute(val, '\m\C\r', '', 'g')})
        return l:data
    else
        " For Vim, l:data is a string, which we return as a list.
        return [l:data]
    endif
endfunction

" Extract data from a system's exit callback.
"
" Params:
"     cb_arglist : List
"         variable-size list of arguments as passed to the callback, which will
"         differ between Neovim and Vim
"
" Returns:
"     Number
"         exit code
"
function! s:system.ExtractExitCallbackData(cb_arglist) abort
    return a:cb_arglist[1]
endfunction

" Get system 'object'.
"
function! cmake#system#Get() abort
    return s:system
endfunction
