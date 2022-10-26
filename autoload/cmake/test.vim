" ==============================================================================
" Location:    autoload/cmake/test.vim
" Description: Functions for running tests
" ==============================================================================

let s:test = {}

let s:buildsys = cmake#buildsys#Get()
let s:logger = cmake#logger#Get()
let s:system = cmake#system#Get()
let s:terminal = cmake#terminal#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get dictionary of test arguments from command-line string.
"
" Params:
"     argstring : String
"         command-line arguments, like test names and additional test options
"
" Returns:
"     Dictionary
"         CMake test options and test names
"
" Example:
"     argstring = --parallel 4 TestOne TestTwo
"     return = {
"         \ 'cmake_test_options': ['--parallel', '4'],
"         \ 'test_names': ['-R', 'TestOne|TestTwo'],
"     \ }
"
function! s:GetTestArgs(argstring) abort
    let l:argdict = {}
    let l:argdict.cmake_test_options = []
    let l:argdict.test_names = []
    let l:arglist = split(a:argstring)
    " Search arguments for those that match the name of a test.
    let l:test_names = []
    for l:t in s:buildsys.GetTests()
        let l:match_res = match(l:arglist, '\m\C^' . l:t)
        if l:match_res != -1
            " If found, get test name and remove from list of arguments.
            let l:test_name = l:arglist[l:match_res]
            let l:test_names += [l:test_name]
            call remove(l:arglist, l:match_res)
        endif
    endfor
    if len(l:test_names) > 0
        let l:argdict.test_names = ['-R', join(l:test_names, '|')]
    endif
    " Get command-line CMake arguments.
    let l:argdict.cmake_test_options = l:arglist
    return l:argdict
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Run CMake-generated tests using CTest.
"
" Params:
"     argstring : String
"         test name and other options
"
function! s:test.Test(argstring) abort
    call s:logger.LogDebug('Invoked: test.Test(%s)', string(a:argstring))
    let l:path_to_current_config = s:buildsys.GetPathToCurrentConfig()
    let l:build_dir = s:system.Path([l:path_to_current_config], v:true)
    let l:command = [g:cmake_test_command, '--test-dir', l:build_dir]
    let l:options = {}
    " Parse additional options.
    let l:options = s:GetTestArgs(a:argstring)
    " Add CMake test options to the command.
    let l:command += g:cmake_test_options
    let l:command += get(l:options, 'cmake_test_options', [])
    " Add test names to the command, if any were provided.
    let l:command += get(l:options, 'test_names', [])
    " Run test command.
    " echo l:command
    call s:terminal.Run(l:command, 'TEST', {})
endfunction

" Get test 'object'.
"
function! cmake#test#Get() abort
    return s:test
endfunction
