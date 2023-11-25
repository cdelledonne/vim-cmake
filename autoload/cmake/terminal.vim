" ==============================================================================
" Location:    autoload/cmake/terminal.vim
" Description: Terminal and console handling
" ==============================================================================

let s:terminal = {}
let s:terminal.term_id = v:null
let s:terminal.console_buffer = -1
let s:terminal.overlay_buffer = -1

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

let s:terminal.overlay_cmd = {}
let s:terminal.overlay_cmd.id = -1
let s:terminal.overlay_cmd.running = v:false

let s:raw_lines_filters = []
let s:full_lines_filters = []

let s:buffer_options = {
    \ 'bufhidden': 'hide',
    \ 'buflisted': v:false,
    \ 'filetype': 'vimcmake',
    \ }

let s:window_options = {
    \ 'number': v:false,
    \ 'relativenumber': v:false,
    \ 'signcolumn': 'auto',
    \ }

let s:statusline_option = {
    \ 'statusline': '[CMake]\ [%{cmake#GetInfo().config}]\ %{cmake#GetInfo().status}',
    \ }

let s:console_buffer_keymaps = {
    \ 'cg': ':CMakeGenerate<CR>',
    \ 'cb': ':CMakeBuild<CR>',
    \ 'ci': ':CMakeInstall<CR>',
    \ 'ct': ':CMakeTest<CR>',
    \ 'cq': ':CMakeClose<CR>',
    \ '<C-C>': ':CMakeStop<CR>',
    \ }

let s:overlay_buffer_keymaps = {
    \ 'cq': ':CMakeCloseOverlay<CR>',
    \ }

let s:fatal_error_signals = {
    \  1: 'SIGHUP',       2: 'SIGINT',       3: 'SIGQUIT',      4: 'SIGILL',
    \  5: 'SIGTRAP',      6: 'SIGABRT',      7: 'SIGBUS',       8: 'SIGFPE',
    \  9: 'SIGKILL',     10: 'SIGUSR1',     11: 'SIGSEGV',     12: 'SIGUSR2',
    \ 13: 'SIGPIPE',     14: 'SIGALRM',     15: 'SIGTERM',     16: 'SIGSTKFLT',
    \ 17: 'SIGCHLD',     18: 'SIGCONT',     19: 'SIGSTOP',     20: 'SIGTSTP',
    \ 21: 'SIGTTIN',     22: 'SIGTTOU',     23: 'SIGURG',      24: 'SIGXCPU',
    \ 25: 'SIGXFSZ',     26: 'SIGVTALRM',   27: 'SIGPROF',     28: 'SIGWINCH',
    \ 29: 'SIGIO',       30: 'SIGPWR',      31: 'SIGSYS',      34: 'SIGRTMIN',
    \ 35: 'SIGRTMIN+1',  36: 'SIGRTMIN+2',  37: 'SIGRTMIN+3',  38: 'SIGRTMIN+4',
    \ 39: 'SIGRTMIN+5',  40: 'SIGRTMIN+6',  41: 'SIGRTMIN+7',  42: 'SIGRTMIN+8',
    \ 43: 'SIGRTMIN+9',  44: 'SIGRTMIN+10', 45: 'SIGRTMIN+11', 46: 'SIGRTMIN+12',
    \ 47: 'SIGRTMIN+13', 48: 'SIGRTMIN+14', 49: 'SIGRTMIN+15', 50: 'SIGRTMAX-14',
    \ 51: 'SIGRTMAX-13', 52: 'SIGRTMAX-12', 53: 'SIGRTMAX-11', 54: 'SIGRTMAX-10',
    \ 55: 'SIGRTMAX-9',  56: 'SIGRTMAX-8',  57: 'SIGRTMAX-7',  58: 'SIGRTMAX-6',
    \ 59: 'SIGRTMAX-5',  60: 'SIGRTMAX-4',  61: 'SIGRTMAX-3',  62: 'SIGRTMAX-2',
    \ 63: 'SIGRTMAX-1',  64: 'SIGRTMAX',
    \ }

let s:const = cmake#const#Get()
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
    call s:system.TermEcho(s:terminal.term_id, l:raw_lines, v:false)
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
    call s:OnCompleteConsoleCommand(l:error, v:false)
endfunction

" Callback for the end of the command running in the overlay window.
"
function! s:OverlayCmdExitCb(...) abort
    call s:logger.LogDebug('Invoked overlay exit callback')
    let l:error = s:system.ExtractExitCallbackData(a:000)
    call s:OnCompleteOverlayCommand()
    if l:error > 128
        let l:signal = l:error - 128
        if has_key(s:fatal_error_signals, l:signal)
            let l:signame = s:fatal_error_signals[l:signal]
            call s:logger.EchoWarn(
                \ 'Executable was interrupted with fatal signal: %s', l:signame)
            call s:logger.LogWarn(
                \ 'Executable was interrupted with fatal signal: %s', l:signame)
        endif
    endif
endfunction

" Define actions to perform when completing/stopping a console command.
"
function! s:OnCompleteConsoleCommand(error, stopped) abort
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
    call s:system.TermEcho(s:terminal.term_id, [''], v:true)
    " Exit terminal mode if inside the console window (useful for Vim).
    call s:TermModeExit()
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
        call s:system.AutocmdRun(l:autocmd)
    endfor
endfunction

" Define actions to perform when completing/stopping an overlay command.
"
function! s:OnCompleteOverlayCommand() abort
    " Reset state
    let s:terminal.overlay_cmd.id = -1
    let s:terminal.overlay_cmd.running = v:false
    " Exit terminal mode if inside the overlay window (useful for Vim).
    call s:TermModeExit()
    " Update statusline.
    let s:terminal.cmd_info = s:terminal.console_cmd_info.NONE
    call s:statusline.Refresh()
endfunction

" Wrapper for s:system.TermModeEnter().
"
function! s:TermModeEnter() abort
    call s:system.TermModeEnter()
endfunction

" Wrapper for s:system.TermModeExit().
"
function! s:TermModeExit() abort
    if s:system.WindowGetID() ==
        \ s:system.BufferGetWindowID(s:terminal.console_buffer)
        if s:terminal.console_cmd.running
            return
        endif
    elseif s:system.WindowGetID() ==
        \ s:system.BufferGetWindowID(s:terminal.overlay_buffer)
        if s:terminal.overlay_cmd.running
            return
        endif
    else
        return
    endif
    call s:system.TermModeExit()
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
    let l:console_win_id = s:system.BufferGetWindowID(s:terminal.console_buffer)
    " For Vim, must go back into Terminal-Job mode for the command's output to
    " be appended to the buffer.
    if !has('nvim')
        call s:system.WindowRun(l:console_win_id, function('s:TermModeEnter'))
    endif
    " Run command.
    let l:options = {}
    let l:options.stdout_cb = function('s:ConsoleCmdStdoutCb')
    let l:options.exit_cb = function('s:ConsoleCmdExitCb')
    let l:options.pty = v:true
    let l:options.width = s:system.WindowGetWidth(l:console_win_id)
    let l:job_id = s:system.JobRun(a:command, v:false, l:options)
    " For Neovim, scroll manually to the end of the terminal buffer while the
    " command's output is being appended.
    call s:system.BufferScrollToEnd(s:terminal.console_buffer)
    return l:job_id
endfunction

" Start arbitrary command in the overlay buffer.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"
" Return:
"     Number
"         job id
"
function! s:OverlayCmdStart(command) abort
    let l:overlay_win_id = s:system.BufferGetWindowID(s:terminal.overlay_buffer)
    " For Vim, must go back into Terminal-Job mode for the command's output to
    " be appended to the buffer.
    if !has('nvim')
        call s:system.WindowRun(l:overlay_win_id, function('s:TermModeEnter'))
    endif
    " Run command.
    let l:options = {}
    let l:options.exit_cb = function('s:OverlayCmdExitCb')
    let l:job_id = s:system.TermRun(a:command, l:options, l:overlay_win_id)
    " Apply buffer options, mappings and autocommands.
    call s:system.BufferSetOptions(s:terminal.overlay_buffer, s:buffer_options)
    call s:system.BufferSetKeymaps(
        \ s:terminal.overlay_buffer, 'n', s:overlay_buffer_keymaps)
    call s:system.BufferSetAutocmds(
        \ s:terminal.overlay_buffer,
        \ 'vimcmake_overlay',
        \ s:overlay_buffer_autocmds
        \ )
    " For Neovim, scroll manually to the end of the terminal buffer while the
    " command's output is being appended.
    call s:system.BufferScrollToEnd(s:terminal.overlay_buffer)
    return l:job_id
endfunction

" Create Vim-CMake buffer and apply local settings.
"
" Params:
"     echo_term : Boolean
"         whether the new buffer must be an echo terminal (job-less terminal to
"         echo data to)
"
" Returns:
"     Number
"         ID of the created buffer
"
function! s:CreateBuffer(window, echo_term) abort
    let l:ids = s:system.BufferCreate(a:window, a:echo_term)
    let l:buffer_id = l:ids['buffer_id']
    if a:echo_term
        let s:terminal.term_id = l:ids['term_id']
        " For console (non-overlay) buffers, the new terminal buffer is spawned
        " above (with s:system.BufferCreate()), thus we can immediately apply
        " buffer options, keymaps and autocommands. For overlay buffers, these
        " buffer-local settings will be applied after spawning the terminal in
        " the overlay window (with OverlayCmdStart()).
        call s:system.BufferSetOptions(l:buffer_id, s:buffer_options)
        call s:system.BufferSetKeymaps(l:buffer_id, 'n', s:console_buffer_keymaps)
        call s:system.BufferSetAutocmds(
            \ l:buffer_id, 'vimcmake_console', s:console_buffer_autocmds)
    endif
    call s:system.WindowSetOptions(a:window, s:window_options)
    if g:cmake_statusline
        call s:system.WindowSetOptions(a:window, s:statusline_option)
    endif
    let l:type = a:echo_term ? 'console' : 'overlay'
    call s:logger.LogDebug('Created %s buffer', l:type)
    return l:ids['buffer_id']
endfunction

" Delete Vim-CMake console buffer.
"
function! s:DeleteConsoleBuffer() abort
    if s:system.BufferExists(s:terminal.console_buffer)
        if s:terminal.console_cmd.running
            call s:logger.EchoError(s:const.errors['CANT_STOP_CONSOLE_JOB'])
            call s:logger.LogError(s:const.errors['CANT_STOP_CONSOLE_JOB'])
            return
        endif
        call s:system.BufferDelete(s:terminal.console_buffer)
    endif
    let s:terminal.console_buffer = -1
endfunction

" Delete Vim-CMake overlay buffer.
"
function! s:DeleteOverlayBuffer() abort
    if s:system.BufferExists(s:terminal.overlay_buffer)
        if s:terminal.overlay_cmd.running
            call s:logger.EchoError(s:const.errors['CANT_STOP_OVERLAY_JOB'])
            call s:logger.LogError(s:const.errors['CANT_STOP_OVERLAY_JOB'])
            return
        endif
        call s:system.BufferDelete(s:terminal.overlay_buffer)
    endif
    let s:terminal.overlay_buffer = -1
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
" Autocommands for buffer events, must be defined after defining the target
" functions themselves.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:console_buffer_autocmds = {
    \ 'BufEnter': function('s:TermModeExit'),
    \ }

let s:overlay_buffer_autocmds = {
    \ 'BufEnter': function('s:TermModeExit'),
    \ }

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Open Vim-CMake console window.
"
" Params:
"     new_buf : Boolean
"         if set, a new buffer is created and the old one is deleted
"     new_overlay : Boolean
"         if set, a new overlay buffer is created
"
function! s:terminal.Open(new_buf, new_overlay) abort
    call s:logger.LogDebug('Invoked: terminal.Open(%s, %s)',
        \  a:new_buf, a:new_overlay)
    " If a Vim-CMake window does not exist, create it.
    if s:system.BufferGetWindowID(l:self.console_buffer) != -1
        let l:cmake_win_id = s:system.BufferGetWindowID(l:self.console_buffer)
    elseif s:system.BufferGetWindowID(l:self.overlay_buffer) != -1
        let l:cmake_win_id = s:system.BufferGetWindowID(l:self.overlay_buffer)
    else
        let l:cmake_win_id = s:system.WindowCreate(
            \ g:cmake_console_position,
            \ g:cmake_console_size,
            \ ['winfixheight', 'winfixwidth'],
            \ )
    endif
    " Create a console buffer if none exist or if a new buffer is requested.
    if l:self.console_buffer == -1 || a:new_buf
        let l:buffer = s:CreateBuffer(l:cmake_win_id, v:true)
        call s:DeleteConsoleBuffer()
        let l:self.console_buffer = l:buffer
    endif
    " Create an overlay buffer if requested.
    if a:new_overlay
        let l:buffer = s:CreateBuffer(l:cmake_win_id, v:false)
        call s:DeleteOverlayBuffer()
        let l:self.overlay_buffer = l:buffer
    endif
    " Show overlay buffer if it exists, otherwise show console buffer.
    if !s:system.WindowSetBuffer(l:cmake_win_id, l:self.overlay_buffer)
        call s:system.WindowSetBuffer(l:cmake_win_id, l:self.console_buffer)
    endif
endfunction

" Focus Vim-CMake console window.
"
function! s:terminal.Focus() abort
    call s:logger.LogDebug('Invoked: terminal.Focus()')
    if s:system.BufferExists(l:self.overlay_buffer)
        call s:system.WindowGoToID(
            \ s:system.BufferGetWindowID(l:self.overlay_buffer))
    else
        call s:system.WindowGoToID(
            \ s:system.BufferGetWindowID(l:self.console_buffer))
    endif
endfunction

" Close Vim-CMake console window.
"
" Params:
"     stop : Boolean
"         if set, the console job and the overlay job are stopped - stopping
"         these jobs fails if there is still a command running inside of the
"         console or overlay
"
function! s:terminal.Close(stop) abort
    call s:logger.LogDebug('Invoked: terminal.Close(%s)', a:stop)
    if s:system.BufferGetWindowID(l:self.console_buffer) != -1
        call s:system.WindowClose(
            \ s:system.BufferGetWindowID(l:self.console_buffer))
    elseif s:system.BufferGetWindowID(l:self.overlay_buffer) != -1
        call s:system.WindowClose(
            \ s:system.BufferGetWindowID(l:self.overlay_buffer))
    endif
    if a:stop
        call s:DeleteConsoleBuffer()
        call s:DeleteOverlayBuffer()
    endif
endfunction

" Toggle Vim-CMake console window.
"
function! s:terminal.Toggle() abort
    call s:logger.LogDebug('Invoked: terminal.Toggle()')
    if s:system.BufferGetWindowID(l:self.console_buffer) == -1 &&
        \ s:system.BufferGetWindowID(l:self.overlay_buffer) == -1
        call l:self.Open(v:false, v:false)
    else
        call l:self.Close(v:false)
    endif
endfunction

" Close Vim-CMake overlay window.
"
function! s:terminal.CloseOverlay() abort
    call s:logger.LogDebug('Invoked: terminal.CloseOverlay()')
    if s:system.BufferGetWindowID(l:self.overlay_buffer) == -1
        return
    endif
    let l:original_win_id = s:system.WindowGetID()
    " Focus overlay window.
    call s:system.WindowGoToID(
        \ s:system.BufferGetWindowID(l:self.overlay_buffer))
    " Switch to Vim-CMake console buffer.
    if s:system.BufferExists(l:self.console_buffer)
        execute 'b ' . l:self.console_buffer
    endif
    " Delete overlay buffer.
    call s:DeleteOverlayBuffer()
    " Go back to previous window if necessary.
    if l:original_win_id != s:system.WindowGetID()
        call s:system.WindowGoToID(l:original_win_id)
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
        call s:logger.EchoError(s:const.errors['COMMAND_RUNNING'])
        call s:logger.LogError(s:const.errors['COMMAND_RUNNING'])
        return
    endif
    let l:self.console_cmd.callbacks_succ = get(a:options, 'callbacks_succ', [])
    let l:self.console_cmd.callbacks_err = get(a:options, 'callbacks_err', [])
    let l:self.console_cmd.autocmds_succ = get(a:options, 'autocmds_succ', [])
    let l:self.console_cmd.autocmds_err = get(a:options, 'autocmds_err', [])
    let l:self.console_cmd_output = []
    " Open Vim-CMake console window, but close overlay first (if it exists).
    call l:self.CloseOverlay()
    call l:self.Open(v:false, v:false)
    let l:self.console_cmd.running = v:true
    " Invoke pre-run autocommands.
    for l:autocmd in get(a:options, 'autocmds_pre', [])
        call s:logger.LogDebug('Executing autocmd %s', l:autocmd)
        call s:system.AutocmdRun(l:autocmd)
    endfor
    " Echo start message to terminal.
    if g:cmake_console_echo_cmd
        let l:msg = printf(
                \ '%sRunning command: %s%s',
                \ "\e[1;35m",
                \ join(a:command),
                \ "\e[0m")
        call s:system.TermEcho(l:self.term_id, [l:msg . "\r"], v:true)
    endif
    " Run command.
    let s:terminal.cmd_info = l:self.console_cmd_info[a:tag]
    let l:self.console_cmd.id = s:ConsoleCmdStart(a:command)
    " Go to Vim-CMake window if requested.
    if g:cmake_jump
        call l:self.Focus()
    endif
endfunction

" Run arbitrary command in an overlay window. The overlay is displayed in the
" same windows as the Vim-CMake console, and is deleted after the completion of
" the command.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"
function! s:terminal.RunOverlay(command) abort
    call s:logger.LogDebug('Invoked: terminal.RunOverlay(%s)', a:command)
    " Prevent executing this function when a command is already running
    if l:self.overlay_cmd.running
        call s:logger.EchoError(s:const.errors['COMMAND_RUNNING_OVERLAY'])
        call s:logger.LogError(s:const.errors['COMMAND_RUNNING_OVERLAY'])
        return
    endif
    " Open overlay window.
    call l:self.Open(v:false, v:true)
    let l:self.overlay_cmd.running = v:true
    " Run command.
    let s:terminal.cmd_info = 'Running command...'
    let l:self.overlay_cmd.id = s:OverlayCmdStart(a:command)
    " Go to Vim-CMake window if requested.
    if g:cmake_jump
        call l:self.Focus()
    endif
endfunction

" Stop command currently running in the Vim-CMake console and in the overlay.
"
function! s:terminal.Stop() abort
    call s:logger.LogDebug('Invoked: terminal.Stop()')
    call s:system.JobStop(l:self.console_cmd.id)
    call s:system.JobStop(l:self.overlay_cmd.id)
    call s:OnCompleteConsoleCommand(0, v:true)
    call s:OnCompleteOverlayCommand()
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
