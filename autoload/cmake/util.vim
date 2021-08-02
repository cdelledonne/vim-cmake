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
            " If found, get absolute path and strip l:marker from it.
            let l:root = fnamemodify(l:marker_path, printf(
                    \ ':.:s?%s??:h', l:marker_path))
            break
        endif
        " Search CWD upward for l:marker, assuming it is a directory.
        let l:marker_path = finddir(l:marker, l:escaped_cwd . ';' . $HOME)
        if len(l:marker_path)
            " If found, get absolute path and strip l:marker from it.
            let l:root = fnamemodify(l:marker_path, printf(
                    \ ':.:s?%s/??:h', l:marker_path))
            break
        endif
    endfor
    " Escape file name.
    return fnameescape(l:root)
endfunction
