" ==============================================================================
" Location:    autoload/cmake/system.vim
" Description: System abstraction layer
" ==============================================================================

let s:system = {}

let s:shell = split(&shell) + split(&shellcmdflag)
let s:stdout_partial_line = {}

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
        " In MS-Windows, must delete existing link, if present.
        if filereadable(a:link_name)
            let l:command = s:shell + ['del', a:link_name]
            call l:self.JobRun(l:command, a:wait, v:null, v:null, v:false)
        endif
        let l:command = s:shell + ['mklink', a:link_name, a:target]
    else
        let l:command = ['ln', '-sf', a:target, a:link_name]
    endif
    call l:self.JobRun(l:command, a:wait, v:null, v:null, v:false)
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
"     pty : Boolean
"         whether to allocate a pseudo terminal for the job
"
" Return:
"     Number
"         job id
"
function! s:system.JobRun(command, wait, stdout_cb, exit_cb, pty) abort
    let l:options = {}
    let l:options['pty'] = a:pty
    " Remove double quotes around command arguments that were quoted by the
    " user. For instance, '-G "Unix Makefiles"' results in '-G Unix Makefiles'.
    call map(a:command, {_, val -> substitute(
                \ val, '\m\C\(^\|[^"\\]\)"\([^"]\|$\)', '\1\2', 'g')})
    if has('nvim')
        if a:stdout_cb isnot# v:null
            let l:options['on_stdout'] = a:stdout_cb
        endif
        if a:exit_cb isnot# v:null
            let l:options['on_exit'] = a:exit_cb
        endif
        " In some cases, the PTY in MS-Windows (ConPTY) uses ANSI escape
        " sequences to move the cursor position (ESC[<n>;<m>H) rather than
        " inseting newline characters. Setting the width of the PTY to be very
        " large and the height to be as small as possible (but larger than 1)
        " seems to circumvent this problem. Hacky, but it seems to work.
        if has('win32')
            let l:options['width'] = 10000
            let l:options['height'] = 2
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
    let l:channel = a:cb_arglist[0]
    let l:data = a:cb_arglist[1]
    if has('nvim')
        let l:eof = (l:data == [''])
        " In Neovim, remove all the CR characters, which are returned when a
        " pseudo terminal is allocated for the job.
        call map(l:data, {_, val -> substitute(val, '\m\C\r', '', 'g')})
        " The first and the last lines may be partial lines, thus they need to
        " be joined on consecutive iterations. See :help channel-lines.
        " When this function is called for the first time for a particular
        " channel, allocate an empty partial line for that channel.
        if !has_key(s:stdout_partial_line, l:channel)
            let s:stdout_partial_line[l:channel] = ''
        endif
        " Append first entry of output list to partial line.
        let s:stdout_partial_line[l:channel] .= remove(l:data, 0)
        " If output list contains more entries, they are all complete lines
        " except for the last entry. Return the saved partial line (which is now
        " complete) and all the complete lines from the list, and save a new
        " partial line (the last entry of the list).
        if len(l:data) > 0
            call insert(l:data, s:stdout_partial_line[l:channel])
            let s:stdout_partial_line[l:channel] = remove(l:data, -1)
        endif
        " At the end of the stream of a channel, remove the dictionary entry for
        " that channel.
        if l:eof
            call remove(s:stdout_partial_line, l:channel)
        endif
    else
        " In Vim, l:data is a string, so we transform it to a list (consisting
        " of a single element).
        let l:data = [l:data]
    endif
    return l:data
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
