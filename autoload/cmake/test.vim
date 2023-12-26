" ==============================================================================
" Location:    autoload/cmake/test.vim
" Description: Functions for running tests
" ==============================================================================

let s:test = {}

let s:buildsys = cmake#buildsys#Get()
let s:const = cmake#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:system = libs#system#Get()
let s:terminal = cmake#terminal#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions and callbacks
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get dictionary of test arguments from command-line string.
"
" Params:
"     args : List
"         command-line arguments, like test names and additional test options
"
" Returns:
"     Dictionary
"         CMake test options and test names
"
" Example:
"     args = ['--parallel', '4', 'TestOne', 'TestTwo']
"     return = {
"         \ 'cmake_test_options': ['--parallel', '4'],
"         \ 'test_names': ['-R', 'TestOne|TestTwo'],
"     \ }
"
function! s:GetTestArgs(args) abort
    let argdict = {}
    let argdict.cmake_test_options = []
    let argdict.test_names = []
    let arglist = deepcopy(a:args)
    " Search arguments for those that match the name of a test.
    let test_names = []
    for t in s:buildsys.GetTests()
        let match_res = match(arglist, '\m\C^' . t)
        if match_res != -1
            " If found, get test name and remove from list of arguments.
            let test_name = arglist[match_res]
            let test_names += [test_name]
            call remove(arglist, match_res)
        endif
    endfor
    if len(test_names) > 0
        let argdict.test_names = ['-R', join(test_names, '|')]
    endif
    " Get command-line CMake arguments.
    let argdict.cmake_test_options = arglist
    return argdict
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Run CMake-generated tests using CTest.
"
" Params:
"     args : List
"         test name(s) and other options
"
function! s:test.Test(args) abort
    call s:logger.LogDebug('Invoked: test.Test(%s)', string(a:args))
    let path_to_current_config = s:buildsys.GetPathToCurrentConfig()
    let build_dir = s:system.Path([path_to_current_config], v:true)
    let command = [g:cmake_test_command, '--test-dir', build_dir]
    let options = {}
    " Parse additional options.
    let options = s:GetTestArgs(a:args)
    " Add CMake test options to the command.
    let command += g:cmake_test_options
    let command += get(options, 'cmake_test_options', [])
    " Add test names to the command, if any were provided.
    let command += get(options, 'test_names', [])
    " Run test command.
    " echo command
    call s:terminal.Run(command, 'TEST', {})
endfunction

" Get test 'object'.
"
function! cmake#test#Get() abort
    return s:test
endfunction
