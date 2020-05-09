" ==============================================================================
" Location:    autoload/cmake.vim
" Description: API functions for Vim-CMake
" ==============================================================================

if exists('g:loaded_airline') && g:loaded_airline
    call airline#add_statusline_func('cmake#statusline#Airline')
    call airline#add_inactive_statusline_func('cmake#statusline#AirlineInactive')
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" API function for cmake#generate#Run().
"
" Params:
" - bg         whether to run the command in the background
" - wait       whether to wait for completion (only for bg == 1)
" - clean      whether to clean before generating
" - [options]  optional parameter to specify CMake options
"
function! cmake#Generate(bg, wait, clean, ...) abort
    if a:0 > 0
        " Get CMake build type from command-line arguments.
        let l:build_type = cmake#generate#GetBuildType(a:1)
        call cmake#statusline#SetBuildInfo(l:build_type)
        " Select build directory based on build type.
        if len(l:build_type)
            call cmake#build#SetBuildDir(l:build_type)
        endif
    endif
    if a:clean
        call cmake#generate#Clean()
    endif
    if a:0 > 0
        call cmake#generate#Run(a:bg, a:wait, a:1)
    else
        call cmake#generate#Run(a:bg, a:wait)
    endif
endfunction

" API function for cmake#generate#Clean().
function! cmake#Clean() abort
    call cmake#generate#Clean()
endfunction

" API function for cmake#build#Run().
"
" Params:
" - bg         whether to run the command in the background
" - wait       whether to wait for completion (only for bg == 1)
" - clean      whether to clean before building
" - [options]  optional parameter to specify target and other options
"
function! cmake#Build(bg, wait, clean, ...) abort
    if a:clean
        call cmake#build#Run(1, 1, 'clean')
    endif
    if a:0 > 0
        call cmake#build#Run(a:bg, a:wait, a:1)
    else
        call cmake#build#Run(a:bg, a:wait)
    endif
endfunction

" API function for cmake#console#Open().
"
" Params:
" - clear  if set, a new buffer is created and the old one is deleted
"
function! cmake#Open(clear) abort
    call cmake#console#Open(a:clear)
endfunction

" API function for cmake#console#Close().
"
function! cmake#Close() abort
    call cmake#console#Close()
endfunction
