" ==============================================================================
" Location:    autoload/cmake/system.vim
" Description: System abstraction layer
" ==============================================================================

let s:system = {}

let s:stdout_partial_line = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:ManipulateCommand(command) abort
    let l:ret_command = []
    for l:arg in a:command
        " Remove double quotes around argument that are quoted. For instance,
        " '-G "Unix Makefiles"' results in '-G Unix Makefiles'.
        let l:quotes_regex = '\m\C\(^\|[^"\\]\)"\([^"]\|$\)'
        let l:arg = substitute(l:arg, l:quotes_regex, '\1\2', 'g')
        " Split arguments that are composed of an option (short '-O' or long
        " '--option') and a follow-up string, where the option and the string
        " are separated by a space.
        let l:split_regex = '\m\C^\(-\w\|--\w\+\)\s\(.\+\)'
        let l:match_list = matchlist(l:arg, l:split_regex)
        if len(l:match_list) > 0
            call add(l:ret_command, l:match_list[1])
            call add(l:ret_command, l:match_list[2])
        else
            call add(l:ret_command, l:arg)
        endif
    endfor
    return l:ret_command
endfunction

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
    let l:components = a:components
    let l:separator = has('win32') ? '\' : '/'
    " Join path components and get absolute path.
    let l:path = join(l:components, l:separator)
    let l:path = simplify(l:path)
    let l:path = fnamemodify(l:path, ':p')
    " If path ends with separator, remove separator from path.
    if match(l:path, '\m\C\' . l:separator . '$') != -1
        let l:path = fnamemodify(l:path, ':h')
    endif
    " Reduce to relative path if requested.
    if a:relative
        " For some reason, reducing the path to relative returns an empty string
        " if the path happens to be the same as CWD. Thus, only reduce the path
        " to relative when it is not CWD, otherwise just return '.'.
        if l:path ==# getcwd()
            let l:path = '.'
        else
            let l:path = fnamemodify(l:path, ':.')
        endif
    endif
    " Simplify path.
    let l:path = simplify(l:path)
    return l:path
endfunction

" Get absolute path to plugin data directory.
"
" Returns:
"     String
"         path to plugin data directory
"
function! s:system.GetDataDir() abort
    if has('nvim')
        let l:editor_data_dir = stdpath('cache')
    else
        " In Neovim, stdpath('cache') resolves to:
        " - on MS-Windows: $TEMP/nvim
        " - on Unix: $XDG_CACHE_HOME/nvim
        if has('win32')
            let l:cache_dir = getenv('TEMP')
        else
            let l:cache_dir = getenv('XDG_CACHE_HOME')
            if l:cache_dir == v:null
                let l:cache_dir = l:self.Path([$HOME, '.cache'], v:false)
            endif
        endif
        let l:editor_data_dir = l:self.Path([l:cache_dir, 'vim'], v:false)
    endif
    return l:self.Path([l:editor_data_dir, 'cmake'], v:false)
endfunction

" Run arbitrary job in the background.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"     wait : Boolean
"         whether to wait for completion
"     options : Dictionary
"         stdout_cb : Funcref
"             stdout callback (can be left unset), which should take a variable
"             number of arguments, and from which
"             s:system.ExtractStdoutCallbackData(a:000) can be called to
"             retrieve the stdout lines
"         exit_cb : Funcref
"             exit callback (can be left unset), which should take a variable
"             number of arguments, and from which
"             s:system.ExtractExitCallbackData(a:000) can be called to retrieve
"             the exit code
"         pty : Boolean
"             whether to allocate a pseudo-terminal for the job (leaving this
"             unset is the same as setting it to v:false)
"         width : Number
"             for PTY jobs, width of the pseudo-terminal (can be left unset)
"         height : Number
"             for PTY jobs, height of the pseudo-terminal (can be left unset)
"         env : Dictionary
"             environment variables to pass to the job (only in Vim)
"
" Return:
"     Number
"         job id
"
function! s:system.JobRun(command, wait, options) abort
    let l:command = s:ManipulateCommand(a:command)
    let l:job_options = {}
    let l:job_options.pty = get(a:options, 'pty', v:false)
    let l:job_options.env = get(a:options, 'env', {})
    if has('nvim')
        if has_key(a:options, 'stdout_cb')
            let l:job_options.on_stdout = a:options.stdout_cb
        endif
        if has_key(a:options, 'exit_cb')
            let l:job_options.on_exit = a:options.exit_cb
        endif
        if has_key(a:options, 'width')
            let l:job_options.width = a:options.width
        endif
        if has_key(a:options, 'height')
            let l:job_options.height = a:options.height
        endif
        " Start job.
        let l:job_id = jobstart(l:command, l:job_options)
    else
        if has_key(a:options, 'stdout_cb')
            let l:job_options.out_cb = a:options.stdout_cb
        endif
        if has_key(a:options, 'exit_cb')
            let l:job_options.exit_cb = a:options.exit_cb
        endif
        " NOTE: currently, this doesn't seem to work in Vim
        " (https://github.com/cdelledonne/vim-cmake/issues/75).
        if has_key(a:options, 'width')
            let l:job_options.env.COLUMNS = a:options.width
        endif
        if l:job_options.pty
            " When allocating a PTY, we need to use 'raw' stdout mode in Vim, so
            " that the stdout stream is not buffered, and thus we don't have to
            " wait for NL characters to receive outout.
            let l:job_options.out_mode = 'raw'
            " Moreover, we need to pass the 'TERM' environment variable
            " explicitly, otherwise Vim sets it to 'dumb', which prevents some
            " programs from producing some ANSI sequences.
            let l:job_options.env.TERM = getenv('TERM')
        endif
        " Start job.
        let l:job_id = job_start(l:command, l:job_options)
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
        while ch_status(a:job_id) !=# 'closed'
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
    catch
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
"     Dictionary
"         raw_lines : List
"             raw stdout lines, useful for echoing directly to the terminal
"         full_lines : List
"             only full stdout lines, useful for post-processing
"
function! s:system.ExtractStdoutCallbackData(cb_arglist) abort
    let l:channel = a:cb_arglist[0]
    let l:data = a:cb_arglist[1]
    if has('nvim')
        let l:raw_lines = l:data
        let l:full_lines = []
        " A list only containing an empty string signals the EOF.
        let l:eof = (l:data == [''])
        " The first and the last lines may be partial lines, thus they need to
        " be joined on consecutive iterations. See :help channel-lines.
        " When this function is called for the first time for a particular
        " channel, allocate an empty partial line buffer for that channel.
        if !has_key(s:stdout_partial_line, l:channel)
            let s:stdout_partial_line[l:channel] = ''
        endif
        " Copy first entry of output data list to partial line buffer.
        let s:stdout_partial_line[l:channel] .= l:data[0]
        " If output data list contains more entries, the remaining entries are
        " all complete lines, except for the last entry. The saved parial line
        " (which is now complete), as well as all the other complete lines, can
        " be added to the list of full lines. The last entry of the data list is
        " saved to the partial line buffer.
        if len(l:data) > 1
            call add(l:full_lines, s:stdout_partial_line[l:channel])
            call extend(l:full_lines, l:data[1:-2])
            let s:stdout_partial_line[l:channel] = l:data[-1]
        endif
        " At the end of the stream of a channel, "flush" any leftover partial
        " line, and remove the dictionary entry for that channel. Leftover
        " partial lines at the end of the stream occur when the job's command
        " does not append a newline at the end of the stream.
        if l:eof
            if len(s:stdout_partial_line[l:channel]) > 0
                call add(l:full_lines, s:stdout_partial_line[l:channel])
            endif
            call remove(s:stdout_partial_line, l:channel)
        endif
    else
        " In Vim, data is a string, so we transform it to a list. Also, there
        " aren't any such thing as non-full lines in Vim, however raw lines can
        " contain NL characters, which we use to delimit full lines.
        let l:raw_lines = [l:data]
        let l:full_lines = split(l:data, '\n')
    endif
    let l:lines = {}
    let l:lines.raw_lines = l:raw_lines
    let l:lines.full_lines = l:full_lines
    return l:lines
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
