" ==============================================================================
" Location:    autoload/cmake/quickfix.vim
" Description: Functions for populating the quickfix window
" ==============================================================================

let s:list = {}
let s:list.items = []
let s:list.title = 'CMakeBuild'
let s:id = -1

let s:filters = [
        \ 'v:val.valid == 1',
        \ 'filereadable(bufname(v:val.bufnr))',
        \ ]

function! cmake#quickfix#Generate() abort
    " Create a list of quickfix items from the output of the last command.
    let l:list = getqflist({'lines': cmake#console#GetLastCmdOutput()})
    let s:list.items = filter(l:list.items, join(s:filters, ' && '))
    " If a quickfix list for Vim-CMake exists, make that list active and replace
    " its items with the new ones.
    if getqflist({'id': s:id}).id == s:id
        let l:current = getqflist({'nr': 0}).nr
        let l:target = getqflist({'id': s:id, 'nr': 0}).nr
        if l:current > l:target
            execute 'silent colder ' . (l:current - l:target)
        elseif l:current < l:target
            execute 'silent cnewer ' . (l:target - l:current)
        endif
        call setqflist([], 'r', {'items': s:list.items})
    " Otherwise, create a new quickfix list.
    else
        call setqflist([], ' ', s:list)
    endif
    let s:id = getqflist({'nr': 0, 'id': 0}).id
endfunction
