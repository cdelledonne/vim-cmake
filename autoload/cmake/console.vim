" ==============================================================================
" Location:    autoload/cmake/console.vim
" Description: Functions for creating and managing the CMake console
" ==============================================================================

let s:console_buffer = -1
let s:console_id = -1
let s:console_script = fnameescape(
        \ join([expand('<sfile>:h:h:h'), 'scripts', 'console.sh'], '/'))
let s:previous_window = -1
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
    augroup cmake
        autocmd WinEnter <buffer> call cmake#console#Enter()
    augroup END
    return bufnr('%')
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
        if winnr() == bufwinnr(s:console_buffer)
            call s:ExitTermMode()
        else
            let s:exit_term_mode = 1
        endif
        call cmake#statusline#Refresh()
        call cmake#switch#SearchForExistingConfigs()
        if g:cmake_jump_on_completion
            if winnr() != bufwinnr(s:console_buffer)
                let s:previous_window = winnr()
            endif
            execute bufwinnr(s:console_buffer) . 'wincmd w'
        endif
        if match(l:data, '\m\CErrors have occurred') >= 0
            if g:cmake_jump_on_error
                if winnr() != bufwinnr(s:console_buffer)
                    let s:previous_window = winnr()
                endif
                execute bufwinnr(s:console_buffer) . 'wincmd w'
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
    let l:current_window = winnr()
    let l:cmake_window = bufwinnr(s:console_buffer)
    if l:cmake_window == -1
        " If a Vim-CMake window does not exist, create it.
        call s:CreateWindow()
        if bufexists(s:console_buffer)
            " If a Vim-CMake buffer exists, open it in the Vim-CMake window, or
            " delete it if a:clear is set.
            if !a:clear
                execute 'b ' . s:console_buffer
                execute l:current_window . 'wincmd w'
                return
            else
                execute 'bd! ' . s:console_buffer
            endif
        endif
        " Create Vim-CMake buffer if none exist, of if the old one was deleted.
        let s:console_buffer = s:CreateBuffer()
    else
        " If a Vim-CMake window exists, and a:clear is set, create a new
        " Vim-CMake buffer and delete the old one.
        if a:clear
            let l:old_buffer = s:console_buffer
            execute bufwinnr(s:console_buffer) . 'wincmd w'
            let s:console_buffer = s:CreateBuffer()
            if bufexists(l:old_buffer) && l:old_buffer != s:console_buffer
                execute 'bd! ' . l:old_buffer
            endif
        endif
    endif
    execute l:current_window . 'wincmd w'
endfunction

" Close Vim-CMake console window.
"
function! cmake#console#Close() abort
    if bufexists(s:console_buffer)
        let l:cmake_window = bufwinnr(s:console_buffer)
        if l:cmake_window != -1
            execute l:cmake_window . 'wincmd q'
        endif
    endif
endfunction

function! cmake#console#Enter() abort
    if winnr() == bufwinnr(s:console_buffer) && s:exit_term_mode
        let s:exit_term_mode = 0
        call s:ExitTermMode()
    endif
endfunction

" Return winnr of the CMake console buffer, or -1 if it does not exist.
"
function! cmake#console#GetWinnr() abort
    return bufwinnr(s:console_buffer)
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
