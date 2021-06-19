" ==============================================================================
" Location:    autoload/cmake/console.vim
" Description: Functions for creating and managing the CMake console
" ==============================================================================

let s:console_buffer = -1
let s:console_id = -1
let s:console_script = fnameescape(
        \ join([expand('<sfile>:h:h:h'), 'scripts', 'console.sh'], '/'))
let s:exit_term_mode = 0
let s:cmd_id = ''

let s:cmd_done = 1
let s:last_cmd_output = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Internal functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Create Vim-CMake buffer and apply local settings.
"
" Returns:
"     Number
"         number of the created buffer
"
function! s:CreateBuffer() abort
    execute 'enew'
    let s:console_id = cmake#job#TermStart(s:console_script,
            \ function('s:CMakeConsoleCb'))
    nnoremap <buffer> <silent> cg :CMakeGenerate<CR>
    nnoremap <buffer> <silent> cb :CMakeBuild<CR>
    nnoremap <buffer> <silent> ci :CMakeInstall<CR>
    nnoremap <buffer> <silent> cq :CMakeClose<CR>
    nnoremap <buffer> <silent> <C-C> :call cmake#command#Stop()<CR>
    setlocal nonumber
    setlocal norelativenumber
    setlocal signcolumn=auto
    setlocal nobuflisted
    setlocal filetype=vimcmake
    setlocal statusline=[CMake]
    setlocal statusline+=\ %{cmake#statusline#GetBuildInfo(0)}
    setlocal statusline+=\ %{cmake#statusline#GetCmdInfo()}
    " Avoid error E37 on :CMakeClose in some Vim instances.
    setlocal bufhidden=hide
    augroup cmake
        autocmd WinEnter <buffer> call cmake#console#OnEnter()
    augroup END
    return bufnr()
endfunction

" Create Vim-CMake window.
"
" Returns:
"     Number
"         number of the created window
"
function! s:CreateWindow() abort
    execute join([g:cmake_console_position, g:cmake_console_size . 'split'])
    setlocal winfixheight
    setlocal winfixwidth
endfunction

" Exit terminal mode.
"
function! s:ExitTermMode() abort
    if mode() ==# 't'
        call feedkeys("\<C-\>\<C-N>", 'n')
    endif
endfunction

" Save console output to list, filtering all the non-printable characters and
" ASCII color codes.
"
" Params:
"     string : String
"         line(s) from command output
"
function! s:SaveCmdOutput(string) abort
    " Remove ASCII color codes from string.
    let l:s = substitute(a:string, '\m\C\%x1B\[[0-9;]*[a-zA-Z]', '', 'g')
    " Split string into list entries.
    let l:l = split(l:s, '\r.')
    let s:last_cmd_output += l:l
endfunction

" Callback for non-background commands (cmake#generate#Run() and
" cmake#build#Run()).
"
function! s:CMakeConsoleCb(...) abort
    let l:data = cmake#job#GetCallbackData(a:000)
    if s:cmd_done
        let s:cmd_done = 0
        let s:last_cmd_output = []
    endif
    call s:SaveCmdOutput(l:data)
    " Look for ETX (end of text) character from console.sh (dirty trick to mark
    " end of command).
    if match(l:data, "\x03") >= 0
        let l:cmd_id = s:cmd_id
        let s:cmd_done = 1
        call cmake#console#SetCmdId('')
        call cmake#build#UpdateTargets()
        if l:cmd_id ==# 'build'
            call cmake#quickfix#Generate()
        endif
        " Exit terminal mode if inside the CMake console window (useful for
        " Vim). Otherwise the terminal mode is exited after WinEnter event.
        if win_getid() == bufwinid(s:console_buffer)
            call s:ExitTermMode()
        else
            let s:exit_term_mode = 1
        endif
        call cmake#statusline#Refresh()
        call cmake#switch#SearchForExistingConfigs()
        if g:cmake_jump_on_completion
            call cmake#console#Focus()
        endif
        if match(l:data, '\m\CErrors have occurred') >= 0
            if g:cmake_jump_on_error
                call cmake#console#Focus()
            endif
            if l:cmd_id ==# 'build'
                doautocmd <nomodeline> User CMakeBuildFailed
            endif
        else
            if l:cmd_id ==# 'build'
                doautocmd <nomodeline> User CMakeBuildSucceeded
            endif
        endif
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Open Vim-CMake console window.
"
" Params:
"     clear : Number
"         if set, a new buffer is created and the old one is deleted
"
function! cmake#console#Open(clear) abort
    let l:original_win_id = win_getid()
    let l:cmake_win_id = bufwinid(s:console_buffer)
    if l:cmake_win_id == -1
        " If a Vim-CMake window does not exist, create it.
        call s:CreateWindow()
        if bufexists(s:console_buffer)
            " If a Vim-CMake buffer exists, open it in the Vim-CMake window, or
            " delete it if a:clear is set.
            if !a:clear
                execute 'b ' . s:console_buffer
                call win_gotoid(l:original_win_id)
                return
            else
                execute 'bd! ' . s:console_buffer
            endif
        endif
        " Create Vim-CMake buffer if none exist, or if the old one was deleted.
        let s:console_buffer = s:CreateBuffer()
    else
        " If a Vim-CMake window exists, and a:clear is set, create a new
        " Vim-CMake buffer and delete the old one.
        if a:clear
            let l:old_buffer = s:console_buffer
            call cmake#console#Focus()
            let s:console_buffer = s:CreateBuffer()
            if bufexists(l:old_buffer) && l:old_buffer != s:console_buffer
                execute 'bd! ' . l:old_buffer
            endif
        endif
    endif
    if l:original_win_id != win_getid()
        call win_gotoid(l:original_win_id)
    endif
endfunction

" Close Vim-CMake console window.
"
function! cmake#console#Close() abort
    if bufexists(s:console_buffer)
        let l:cmake_win_id = bufwinid(s:console_buffer)
        if l:cmake_win_id != -1
            execute win_id2win(l:cmake_win_id) . 'wincmd q'
        endif
    endif
endfunction

function! cmake#console#OnEnter() abort
    if winnr() == bufwinnr(s:console_buffer) && s:exit_term_mode
        let s:exit_term_mode = 0
        call s:ExitTermMode()
    endif
endfunction

" Focus Vim-CMake window.
"
function! cmake#console#Focus() abort
    call win_gotoid(bufwinid(s:console_buffer))
endfunction

" Return window ID of the Vim-CMake console, or -1 if it does not exist.
"
function! cmake#console#GetWinID() abort
    return bufwinid(s:console_buffer)
endfunction

" Return buffer number of the Vim-CMake buffer, or -1 if it does not exist.
"
function! cmake#console#GetBufferNr() abort
    return s:console_buffer
endfunction

" Return job_id of the CMake console buffer, or -1 if it does not exist.
"
function! cmake#console#GetID() abort
    return s:console_id
endfunction

" Return output of the last command as a list of strings.
"
function! cmake#console#GetLastCmdOutput() abort
    return s:last_cmd_output
endfunction

" Set ID of command that is currently executing.
"
" Params:
"     id : String
"         command ID, can be 'generate', 'build', 'install', or ''
"
function! cmake#console#SetCmdId(id) abort
    if a:id ==# 'generate'
        let s:cmd_id = a:id
        call cmake#statusline#SetCmdInfo('Generating buildsystem...')
    elseif a:id ==# 'build'
        let s:cmd_id = a:id
        call cmake#statusline#SetCmdInfo('Building...')
    elseif a:id ==# 'install'
        let s:cmd_id = a:id
        call cmake#statusline#SetCmdInfo('Installing...')
    else
        let s:cmd_id = ''
        call cmake#statusline#SetCmdInfo('')
    endif
endfunction
