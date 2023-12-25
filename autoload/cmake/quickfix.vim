" ==============================================================================
" Location:    autoload/cmake/quickfix.vim
" Description: Functions for populating the quickfix window
" ==============================================================================

let s:quickfix = {}
let s:quickfix.list = {}
let s:quickfix.list.items = []
let s:quickfix.list.title = 'CMakeBuild'
let s:quickfix.id = -1

let s:filters = [
    \ 'v:val.valid == 1',
    \ 'filereadable(bufname(v:val.bufnr))',
    \ ]

let s:logger = cmake#logger#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate Quickfix list from lines
"
" Params:
"     lines_to_parse : List
"         list of lines to parse to generate Quickfix list
"
function! s:quickfix.Generate(lines_to_parse) abort
    call s:logger.LogDebug('Invoked: s:quickfix.Generate()')
    " Create a list of quickfix items from the output of the last command.
    let list = getqflist({'lines': a:lines_to_parse})
    let self.list.items = filter(list.items, join(s:filters, ' && '))
    " If a quickfix list for Vim-CMake exists, make that list active and replace
    " its items with the new ones.
    if getqflist({'id': self.id}).id == self.id
        let current = getqflist({'nr': 0}).nr
        let target = getqflist({'id': self.id, 'nr': 0}).nr
        if current > target
            execute 'silent colder ' . (current - target)
        elseif current < target
            execute 'silent cnewer ' . (target - current)
        endif
        call setqflist([], 'r', {'items': self.list.items})
        call s:logger.LogDebug('Replaced existing Quickfix list')
    " Otherwise, create a new quickfix list.
    else
        call setqflist([], ' ', self.list)
        call s:logger.LogDebug('Created new Quickfix list')
    endif
    let self.id = getqflist({'nr': 0, 'id': 0}).id
endfunction

function! cmake#quickfix#Get() abort
    return s:quickfix
endfunction
