" ==============================================================================
" Location:    autoload/cmake.vim
" Description: API functions and global data for Vim-CMake
" ==============================================================================

let s:cmake = {}
let s:cmake.plugin_version = '0.6.2'
let s:cmake.project_name = ''

let s:buildsys = cmake#buildsys#Get()
let s:build = cmake#build#Get()
let s:terminal = cmake#terminal#Get()

" Print news of new Vim-CMake versions.
call cmake#util#PrintNews(s:cmake.plugin_version, {
        \ '0.2.0': ['Vim-CMake has a new feature, run `:help cmake-switch`'],
        \ '0.3.0': ['Vim-CMake has a new feature, run `:help cmake-quickfix`'],
        \ '0.4.0': ['Vim-CMake has a new config option `g:cmake_generate_options`'],
        \ '0.5.0': ['Vim-CMake has a new feature, run `:help cmake-events`'],
        \ '0.6.0': [
                \ 'Vim-CMake has a new config option `g:cmake_build_dir_location`',
                \ 'Vim-CMake has improved :CMakeGenerate, run `:help cmake-generate`'
        \ ],
        \ })

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" API function for :CMakeGenerate and <Plug>(CMakeGenerate).
"
" Params:
"     clean : Number
"         whether to clean before generating
"     a:1 : String
"         (optional) build configuration and additional CMake options
"
function! cmake#Generate(clean, ...) abort
    call s:buildsys.Generate(a:clean, join(a:000))
endfunction

" API function for :CMakeClean and <Plug>(CMakeClean).
"
function! cmake#Clean() abort
    call s:buildsys.Clean()
endfunction

" API function for :CMakeSwitch.
"
" Params:
"     a:1 : String
"         build configuration
"
function! cmake#Switch(...) abort
    call s:buildsys.Switch(a:1)
endfunction

" API function for completion for :CMakeSwitch.
"
" Params:
"     arg_lead : String
"         the leading portion of the argument currently being completed
"     cmd_line : String
"         the entire command line
"     cursor_pos : Number
"         the cursor position in the command line (byte index)
"
" Returns:
"     String
"         stringified list of existing configuration directories
"
function! cmake#GetConfigs(arg_lead, cmd_line, cursor_pos) abort
    return join(s:buildsys.GetConfigs(), "\n")
endfunction

" API function for :CMakeBuild and <Plug>(CMakeBuild).
"
" Params:
"     clean : Number
"         whether to clean before building
"     a:1 : String
"         (optional) target and other build options
"
function! cmake#Build(clean, ...) abort
    call s:build.Build(a:clean, join(a:000))
endfunction

" API function for :CMakeInstall and <Plug>(CMakeInstall).
"
function! cmake#Install() abort
    call s:build.Install()
endfunction

" API function for completion for :CMakeBuild.
"
" API function for completion for :CMakeBuild.
"
" Params:
"     arg_lead : String
"         the leading portion of the argument currently being completed
"     cmd_line : String
"         the entire command line
"     cursor_pos : Number
"         the cursor position in the command line (byte index)
"
" Returns:
"     String
"         available targets, one per line
"
function! cmake#GetBuildTargets(arg_lead, cmd_line, cursor_pos) abort
    return join(s:buildsys.GetTargets(), "\n")
endfunction

" API function for :CMakeStop.
"
function! cmake#Stop() abort
    call s:terminal.Stop()
endfunction

" API function for :CMakeOpen.
"
function! cmake#Open() abort
    call s:terminal.Open(v:false)
endfunction

" API function for :CMakeClose.
"
function! cmake#Close() abort
    call s:terminal.Close()
endfunction
