" ==============================================================================
" Location:    autoload/cmake/terminal.vim
" Description: Terminal abstraction layer
" ==============================================================================

let s:terminal = {}
let s:terminal.console_buffer = -1

let s:terminal.cmd_info = ''
let s:terminal.console_cmd_info = {}
let s:terminal.console_cmd_info.GENERATE = 'Generating buildsystem...'
let s:terminal.console_cmd_info.BUILD = 'Building...'
let s:terminal.console_cmd_info.INSTALL = 'Installing...'
let s:terminal.console_cmd_info.TEST = 'Running tests...'
let s:terminal.console_cmd_info.NONE = ''

let s:terminal.console_cmd_output = []
let s:terminal.console_cmd = {}
let s:terminal.console_cmd.id = -1
let s:terminal.console_cmd.running = v:false
let s:terminal.console_cmd.callbacks_succ = []
let s:terminal.console_cmd.callbacks_err = []
let s:terminal.console_cmd.autocmds_succ = []
let s:terminal.console_cmd.autocmds_err = []

let s:term_tty = ''
let s:term_chan_id = -1
let s:exit_term_mode = 0

let s:raw_lines_filters = []
let s:full_lines_filters = []

let s:logger = cmake#logger#Get()
let s:statusline = cmake#statusline#Get()
let s:system = cmake#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ANSI sequence filters
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" https://en.wikipedia.org/wiki/ANSI_escape_code
" https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences

let s:cr = '\r'
let s:ansi_esc = '\e'
let s:ansi_csi = s:ansi_esc . '\['
let s:ansi_st = '\(\%x07\|\\\)'

" Remove/replace ANSI sequences from raw lines (these sequences would mess up
" the terminal) and from full lines:
"
" | Sequence             | Description                 | Replace with    |
" |----------------------|-----------------------------|-----------------|
" | CSI <n> J            | Erase display (Windows)     | ---             |
" | CSI <y> ; <x> H      | Move cursor (Windows)       | Carriage return |
"
if has('win32')
    let s:filter = {'pat': s:ansi_csi . '\d*J', 'sub': ''}
    call add(s:raw_lines_filters, s:filter)
    call add(s:full_lines_filters, s:filter)
    let s:filter = {'pat': s:ansi_csi . '\(\d\+;\)*\d*H', 'sub': '\r'}
    call add(s:raw_lines_filters, s:filter)
    call add(s:full_lines_filters, s:filter)
endif

" Remove/replace remaining ANSI sequences from full lines:
"
" | Sequence             | Description                 | Replace with    |
" |----------------------|-----------------------------|-----------------|
" | CR                   | Carriage return             | ---             |
" | CSI <n> ; <o> m      | Text formatting             | ---             |
" | CSI K                | Erase from cursor to EOL    | ---             |
" | CSI <n> X            | Erase from cursor (Windows) | ---             |
" | CSI ? 25 [h|l]       | Hide/show cursor (Windows)  | ---             |
" | ESC ] 0 ; <str> <ST> | Console title (Windows)     | ---             |
" | CSI <n> C            | Move forward (Windows)      | Space           |
"
let s:filter = {'pat': s:cr, 'sub': ''}
call add(s:full_lines_filters, s:filter)
let s:filter = {'pat': s:ansi_csi . '\(\d\+;\)*\d*m', 'sub': ''}
call add(s:full_lines_filters, s:filter)
let s:filter = {'pat': s:ansi_csi . 'K', 'sub': ''}
call add(s:full_lines_filters, s:filter)
if has('win32')
    let s:filter = {'pat': s:ansi_csi . '\d*X', 'sub': ''}
    call add(s:full_lines_filters, s:filter)
    let s:filter = {'pat': s:ansi_csi . '?25[hl]', 'sub': ''}
    call add(s:full_lines_filters, s:filter)
    let s:filter = {'pat': s:ansi_esc . '\]' . '0;.*' . s:ansi_st, 'sub': ''}
    call add(s:full_lines_filters, s:filter)
    let s:filter = {
        \ 'pat': s:ansi_csi . '\(\d*\)C',
        \ 'sub': '\=repeat('' '', submatch(1))'
        \ }
    call add(s:full_lines_filters, s:filter)
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Callback for the stdout of the command running in the Vim-CMake console.
"
function! s:ConsoleCmdStdoutCb(...) abort
    let l:data = s:system.ExtractStdoutCallbackData(a:000)
    let l:raw_lines = l:data.raw_lines
    let l:full_lines = l:data.full_lines
    " Filter raw lines and echo them to the terminal
    call map(l:raw_lines, {_, val -> s:FilterLine(val, s:raw_lines_filters)})
    call s:TermEcho(l:raw_lines, v:false)
    " Filter full lines and save them in list of command output.
    call map(l:full_lines, {_, val -> s:FilterLine(val, s:full_lines_filters)})
    let s:terminal.console_cmd_output += l:full_lines
endfunction

" Callback for the end of the command running in the Vim-CMake console.
"
function! s:ConsoleCmdExitCb(...) abort
    call s:logger.LogDebug('Invoked console exit callback')
    " Waiting for the job's channel to be closed ensures that all output has
    " been processed. This is useful in Vim, where buffered stdout may still
    " come in after entering this function.
    call s:system.ChannelWait(s:terminal.console_cmd.id)
    let l:error = s:system.ExtractExitCallbackData(a:000)
    call s:OnCompleteCommand(l:error, v:false)
endfunction

" Enter terminal mode.
"
function! s:EnterTermMode() abort
    if mode() !=# 't'
        execute 'normal! i'
    endif
endfunction

" Exit terminal mode.
"
function! s:ExitTermMode() abort
    if mode() ==# 't'
        call feedkeys("\<C-\>\<C-N>", 'n')
    endif
endfunction

" Define actions to perform when completing/stopping a command.
"
function! s:OnCompleteCommand(error, stopped) abort
    if a:error == 0
        let l:callbacks = s:terminal.console_cmd.callbacks_succ
        let l:autocmds = s:terminal.console_cmd.autocmds_succ
    else
        let l:callbacks = s:terminal.console_cmd.callbacks_err
        let l:autocmds = s:terminal.console_cmd.autocmds_err
    endif
    " Reset state
    let s:terminal.console_cmd.id = -1
    let s:terminal.console_cmd.running = v:false
    let s:terminal.console_cmd.callbacks_succ = []
    let s:terminal.console_cmd.callbacks_err = []
    let s:terminal.console_cmd.autocmds_succ = []
    let s:terminal.console_cmd.autocmds_err = []
    " Append empty line to terminal.
    call s:TermEcho([''], v:true)
    " Exit terminal mode if inside the Vim-CMake console window (useful for
    " Vim). Otherwise the terminal mode is exited after WinEnter event.
    if win_getid() == bufwinid(s:terminal.console_buffer)
        call s:ExitTermMode()
    else
        let s:exit_term_mode = 1
    endif
    " Update statusline.
    let s:terminal.cmd_info = s:terminal.console_cmd_info.NONE
    call s:statusline.Refresh()
    " The rest of the tasks are not to be carried out if the running command was
    " stopped by the user.
    if a:stopped
        return
    endif
    " Focus Vim-CMake console window, if requested.
    if g:cmake_jump_on_completion
        call s:terminal.Focus()
    else
        if a:error != 0 && g:cmake_jump_on_error
            call s:terminal.Focus()
        endif
    endif
    " Handle callbacks and autocmds.
    " Note: Funcref variable names must start with a capital.
    for l:Callback in l:callbacks
        call s:logger.LogDebug('Callback invoked: %s()', l:Callback)
        call l:Callback()
    endfor
    for l:autocmd in l:autocmds
        call s:logger.LogDebug('Executing autocmd %s', l:autocmd)
        if exists('#User' . '#' . l:autocmd)
            execute 'doautocmd <nomodeline> User ' . l:autocmd
        endif
    endfor
endfunction

" Define actions to perform when entering the Vim-CMake console window.
"
function! s:OnEnterConsoleWindow() abort
    if winnr() == bufwinnr(s:terminal.console_buffer) && s:exit_term_mode
        let s:exit_term_mode = 0
        call s:ExitTermMode()
    endif
endfunction

" Start arbitrary command with output to be displayed in Vim-CMake console.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"
" Return:
"     Number
"         job id
"
function! s:ConsoleCmdStart(command) abort
    let l:console_win_id = bufwinid(s:terminal.console_buffer)
    " For Vim, must go back into Terminal-Job mode for the command's output to
    " be appended to the buffer.
    if !has('nvim')
        call win_execute(l:console_win_id, 'call s:EnterTermMode()', '')
    endif
    " Run command.
    let l:options = {}
    let l:options.stdout_cb = function('s:ConsoleCmdStdoutCb')
    let l:options.exit_cb = function('s:ConsoleCmdExitCb')
    let l:options.pty = v:true
    let l:options.width = winwidth(l:console_win_id)
    let l:job_id = s:system.JobRun(a:command, v:false, l:options)
    " For Neovim, scroll manually to the end of the terminal buffer while the
    " command's output is being appended.
    if has('nvim')
        let l:buffer_length = nvim_buf_line_count(s:terminal.console_buffer)
        call nvim_win_set_cursor(l:console_win_id, [l:buffer_length, 0])
    endif
    return l:job_id
endfunction

" Create Vim-CMake window.
"
" Returns:
"     Number
"         number of the created window
"
function! s:CreateConsoleWindow() abort
    execute join([g:cmake_console_position, g:cmake_console_size . 'split'])
    setlocal winfixheight
    setlocal winfixwidth
    call s:logger.LogDebug('Created console window')
endfunction

" Create Vim-CMake buffer and apply local settings.
"
" Returns:
"     Number
"         number of the created buffer
"
function! s:CreateConsoleBuffer() abort
    execute 'enew'
    call s:TermSetup()
    nnoremap <buffer> <silent> cg :CMakeGenerate<CR>
    nnoremap <buffer> <silent> cb :CMakeBuild<CR>
    nnoremap <buffer> <silent> ci :CMakeInstall<CR>
    nnoremap <buffer> <silent> ct :CMakeTest<CR>
    nnoremap <buffer> <silent> cq :CMakeClose<CR>
    nnoremap <buffer> <silent> <C-C> :CMakeStop<CR>
    setlocal nonumber
    setlocal norelativenumber
    setlocal signcolumn=auto
    setlocal nobuflisted
    setlocal filetype=vimcmake
    if g:cmake_statusline
        setlocal statusline=[CMake]
        setlocal statusline+=\ [%{cmake#GetInfo().config}]
        setlocal statusline+=\ %{cmake#GetInfo().status}
    endif
    " Avoid error E37 on :CMakeClose in some Vim instances.
    setlocal bufhidden=hide
    augroup vimcmake
        autocmd WinEnter <buffer> call s:OnEnterConsoleWindow()
    augroup END
    return bufnr()
    call s:logger.LogDebug('Created console buffer')
endfunction

" Setup Vim-CMake console terminal.
"
function! s:TermSetup() abort
    " Open job-less terminal to echo command outputs to.
    let l:options = {}
    if has('nvim')
        let s:term_chan_id = nvim_open_term(bufnr(''), l:options)
    else
        let l:options.curwin = 1
        let l:term = term_start('NONE', l:options)
        let s:term_tty = term_gettty(l:term, 1)
        call term_setkill(l:term, 'term')
    endif
endfunction

" Echo strings to terminal.
"
" Params:
"     data : List
"         list of strings to echo
"     newline : Boolean
"         whether to terminate with newline
"
function! s:TermEcho(data, newline) abort
    if len(a:data) == 0
        return
    endif
    if a:newline
        call add(a:data, '')
    endif
    if has('nvim')
        call chansend(s:term_chan_id, a:data)
    else
        " Use binary mode 'b' such that there isn't a NL character at the end of
        " the last line to write.
        call writefile(a:data, s:term_tty, 'b')
    endif
endfunction

" Filter stdout line to remove/replace ANSI sequences.
"
" Params:
"     line : String
"         line to filter
"     filters : List
"         list of {'pat': <pattern>, 'rep': <replacement>}
"
" Returns:
"     String
"         filtered line
"
function! s:FilterLine(line, filters) abort
    let l:line = a:line
    for l:filter in a:filters
        let l:line = substitute(l:line, l:filter.pat, l:filter.sub, 'g')
    endfor
    return l:line
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Open Vim-CMake console window.
"
" Params:
"     clear : Boolean
"         if set, a new buffer is created and the old one is deleted
"
function! s:terminal.Open(clear) abort
    call s:logger.LogDebug('Invoked: terminal.Open(%s)', a:clear)
    let l:original_win_id = win_getid()
    let l:cmake_win_id = bufwinid(l:self.console_buffer)
    if l:cmake_win_id == -1
        " If a Vim-CMake window does not exist, create it.
        call s:CreateConsoleWindow()
        if bufexists(l:self.console_buffer)
            " If a Vim-CMake buffer exists, open it in the Vim-CMake window, or
            " delete it if a:clear is set.
            if !a:clear
                execute 'b ' . l:self.console_buffer
                call win_gotoid(l:original_win_id)
                return
            else
                execute 'bd! ' . l:self.console_buffer
            endif
        endif
        " Create Vim-CMake buffer if none exist, or if the old one was deleted.
        let l:self.console_buffer = s:CreateConsoleBuffer()
    else
        " If a Vim-CMake window exists, and a:clear is set, create a new
        " Vim-CMake buffer and delete the old one.
        if a:clear
            let l:old_buffer = l:self.console_buffer
            call l:self.Focus()
            let l:self.console_buffer = s:CreateConsoleBuffer()
            if bufexists(l:old_buffer) && l:old_buffer != l:self.console_buffer
                execute 'bd! ' . l:old_buffer
            endif
        endif
    endif
    if !g:cmake_jump
        if l:original_win_id != win_getid()
            call win_gotoid(l:original_win_id)
        endif
    endif
endfunction

" Focus Vim-CMake console window.
"
function! s:terminal.Focus() abort
    call s:logger.LogDebug('Invoked: terminal.Focus()')
    call win_gotoid(bufwinid(l:self.console_buffer))
endfunction

" Close Vim-CMake console window.
"
function! s:terminal.Close() abort
    call s:logger.LogDebug('Invoked: terminal.Close()')
    if bufexists(l:self.console_buffer)
        let l:cmake_win_id = bufwinid(l:self.console_buffer)
        if l:cmake_win_id != -1
            execute win_id2win(l:cmake_win_id) . 'wincmd q'
        endif
    endif
endfunction

" Run arbitrary command in the Vim-CMake console.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"     tag : String
"         command tag, must be an item of keys(l:self.console_cmd_info)
"     options : Dictionary
"         callbacks_succ : List
"             list of callbacks (Funcref) to be invoked upon successful
"             completion of the command
"         callbacks_err : List
"             list of callbacks (Funcref) to be invoked upon unsuccessful
"             completion of the command
"         autocmds_pre : List
"             list of autocmds (String) to be invoked before running the command
"         autocmds_succ : List
"             list of autocmds (String) to be invoked upon successful completion
"             of the command
"         autocmds_err : List
"             list of autocmds (String) to be invoked upon unsuccessful
"             completion of the command
"
function! s:terminal.Run(command, tag, options) abort
    call s:logger.LogDebug('Invoked: terminal.Run(%s, %s, %s)',
            \ a:command, string(a:tag), string(a:options))
    call assert_notequal(index(keys(l:self.console_cmd_info), a:tag), -1)
    " Prevent executing this function when a command is already running
    if l:self.console_cmd.running
        call s:logger.EchoError('Another CMake command is already running')
        call s:logger.LogError('Another CMake command is already running')
        return
    endif
    let l:self.console_cmd.running = v:true
    let l:self.console_cmd.callbacks_succ = get(a:options, 'callbacks_succ', [])
    let l:self.console_cmd.callbacks_err = get(a:options, 'callbacks_err', [])
    let l:self.console_cmd.autocmds_succ = get(a:options, 'autocmds_succ', [])
    let l:self.console_cmd.autocmds_err = get(a:options, 'autocmds_err', [])
    let l:self.console_cmd_output = []
    " Open Vim-CMake console window.
    call l:self.Open(v:false)
    " Invoke pre-run autocommands.
    for l:autocmd in get(a:options, 'autocmds_pre', [])
        call s:logger.LogDebug('Executing autocmd %s', l:autocmd)
        if exists('#User' . '#' . l:autocmd)
            execute 'doautocmd <nomodeline> User ' . l:autocmd
        endif
    endfor
    " Echo start message to terminal.
    if g:cmake_console_echo_cmd
        let l:msg = printf(
                \ '%sRunning command: %s%s',
                \ "\e[1;35m",
                \ join(a:command),
                \ "\e[0m")
        call s:TermEcho([l:msg . "\r"], v:true)
    endif
    " Run command.
    let s:terminal.cmd_info = l:self.console_cmd_info[a:tag]
    let l:self.console_cmd.id = s:ConsoleCmdStart(a:command)
    " Jump to Vim-CMake console window if requested.
    if g:cmake_jump
        call l:self.Focus()
    endif
endfunction

" Stop command currently running in the Vim-CMake console.
"
function! s:terminal.Stop() abort
    call s:logger.LogDebug('Invoked: terminal.Stop()')
    call s:system.JobStop(l:self.console_cmd.id)
    call s:OnCompleteCommand(0, v:true)
endfunction

" Get output from the last command run.
"
" Returns
"     List:
"         output from the last command, as a list of strings
"
function! s:terminal.GetOutput() abort
    return l:self.console_cmd_output
endfunction

" Get current command info
"
" Returns:
"     String
"         current command info
"
function! s:terminal.GetCmdInfo() abort
    return l:self.cmd_info
endfunction

" Get terminal 'object'.
"
function! cmake#terminal#Get() abort
    return s:terminal
endfunction
