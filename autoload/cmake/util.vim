" ==============================================================================
" Location:    autoload/cmake/util.vim
" Description: Utility functions
" ==============================================================================

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find project root by looking for g:cmake_root_markers upwards.
"
" Returns:
"     String
"         escaped path to the root of the project
"
function! cmake#util#FindProjectRoot() abort
    let l:root = getcwd()
    let l:escaped_cwd = fnameescape(getcwd())
    for l:marker in g:cmake_root_markers
        " Search CWD upward for l:marker, assuming it is a file.
        let l:marker_path = findfile(l:marker, l:escaped_cwd . ';' . $HOME)
        if len(l:marker_path)
            " If found, strip l:marker from it.
            let l:root = fnamemodify(l:marker_path, ':h')
            break
        endif
        " Search CWD upward for l:marker, assuming it is a directory.
        let l:marker_path = finddir(l:marker, l:escaped_cwd . ';' . $HOME)
        if len(l:marker_path)
            " If found, strip l:marker from it.
            let l:root = fnamemodify(l:marker_path, ':h')
            break
        endif
    endfor
    " Reduce path to relative to CWD, if possible.
    return fnamemodify(l:root, ':.')
endfunction
