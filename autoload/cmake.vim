" ==============================================================================
" Location:    autoload/cmake.vim
" Description: API functions and global data for Vim-CMake
" ==============================================================================

let s:build = cmake#build#Get()
let s:buildsys = cmake#buildsys#Get()
let s:const = cmake#const#Get()
let s:fileapi = cmake#fileapi#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:terminal = cmake#terminal#Get()
let s:test = cmake#test#Get()

" Print news of new Vim-CMake versions.
let s:news_items = libs#util#FilterNews(
    \ s:const.plugin_name, s:const.plugin_version, s:const.plugin_news)
for s:news_item in s:news_items
    call s:logger.EchoInfo(s:news_item)
endfor

" Log config options.
call s:logger.LogInfo('Configuration options:')
for s:cvar in sort(keys(s:const.config_vars))
    call s:logger.LogInfo('> g:%s: %s', s:cvar, string(g:[s:cvar]))
endfor

" Initialize project variables and set up autocmd to reinitialize in case of a
" directory change.
call s:buildsys.Init()
if g:cmake_reinit_on_dir_changed
    augroup vimcmake
        autocmd DirChanged * call s:buildsys.Init()
    augroup END
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" API function for :CMakeGenerate and <Plug>(CMakeGenerate).
"
" Params:
"     clean : Number
"         whether to clean before generating
"     a:000 : List
"         (optional) build configuration and additional CMake options
"
function! cmake#Generate(clean, ...) abort
    let args = split(join(a:000))
    call s:logger.LogDebug(
        \ 'API invoked: cmake#Generate(%s, %s)', a:clean, string(args))
    call s:buildsys.Generate(a:clean, args)
endfunction

" API function for :CMakeClean and <Plug>(CMakeClean).
"
function! cmake#Clean() abort
    call s:logger.LogDebug('API invoked: cmake#Clean()')
    call s:buildsys.Clean()
endfunction

" API function for :CMakeSwitch.
"
" Params:
"     a:1 : String
"         build configuration
"
function! cmake#Switch(...) abort
    call s:logger.LogDebug('API invoked: cmake#Switch(%s)', string(a:1))
    call s:buildsys.Switch(a:1)
endfunction

" API function for :CMakeBuild and <Plug>(CMakeBuild).
"
" Params:
"     clean : Number
"         whether to clean before building
"     a:000 : List
"         (optional) target and other build options
"
function! cmake#Build(clean, ...) abort
    let args = split(join(a:000))
    call s:logger.LogDebug(
        \ 'API invoked: cmake#Build(%s, %s)', a:clean, string(args))
    call s:build.Build(a:clean, args)
endfunction

" API function for :CMakeInstall and <Plug>(CMakeInstall).
"
function! cmake#Install() abort
    call s:logger.LogDebug('API invoked: cmake#Install()')
    call s:build.Install()
endfunction

" API function for :CMakeRun.
"
" Params:
"     target : String
"         executable target name and optional arguments
"     a:000 : List
"         (optional) program arguments
"
function! cmake#Run(target, ...) abort
    let args = split(join(a:000))
    call s:logger.LogDebug(
        \ 'API invoked: cmake#Run(%s, %s)', a:target, string(args))
    call s:buildsys.Run(a:target, args)
endfunction

" API function for :CMakeTest and <Plug>(CMakeTest).
"
" Params:
"     a:000 : String
"         (optional) test name(s) and other test options
"
function! cmake#Test(...) abort
    let args = split(join(a:000))
    call s:logger.LogDebug('API invoked: cmake#Test(%s)', string(args))
    call s:test.Test(args)
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
"         existing configuration directories, one per line
"
function! cmake#GetConfigs(arg_lead, cmd_line, cursor_pos) abort
    return join(s:buildsys.GetConfigs(), "\n")
endfunction

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
    call s:logger.LogDebug('API invoked: cmake#GetBuildTargets()')
    try
        call s:fileapi.Parse(s:buildsys.GetPathToCurrentConfig())
    catch /vim-cmake-fileapi-noindex/
        call s:logger.EchoWarn(s:const.errors['FILEAPI_NORESP'])
        call s:logger.LogWarn(s:const.errors['FILEAPI_NORESP'])
    endtry
    return join(s:fileapi.GetBuildTargets(), "\n")
endfunction

" API function for completion for :CMakeRun.
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
"         available executable targets, one per line
"
function! cmake#GetExecTargets(arg_lead, cmd_line, cursor_pos) abort
    try
        call s:fileapi.Parse(s:buildsys.GetPathToCurrentConfig())
    catch /vim-cmake-fileapi-noindex/
        call s:logger.EchoWarn(s:const.errors['FILEAPI_NORESP'])
        call s:logger.LogWarn(s:const.errors['FILEAPI_NORESP'])
    endtry
    return join(sort(keys(s:fileapi.GetExecTargets())), "\n")
endfunction

" API function for completion for :CMakeTest.
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
"         available tests, one per line
"
function! cmake#GetTests(arg_lead, cmd_line, cursor_pos) abort
    return join(s:buildsys.GetTests(v:false), "\n")
endfunction

" API function for :CMakeStop.
"
function! cmake#Stop() abort
    call s:logger.LogDebug('API invoked: cmake#Stop()')
    call s:terminal.Stop()
endfunction

" API function for :CMakeOpen.
"
function! cmake#Open() abort
    call s:logger.LogDebug('API invoked: cmake#Open()')
    call s:terminal.Open(v:false, v:false)
endfunction

" API function for :CMakeClose.
"
function! cmake#Close(stop) abort
    call s:logger.LogDebug('API invoked: cmake#Close(%s)', a:stop)
    call s:terminal.Close(a:stop)
endfunction

" API function for :CMakeToggle.
"
function! cmake#Toggle() abort
    call s:logger.LogDebug('API invoked: cmake#Toggle()')
    call s:terminal.Toggle()
endfunction

" API function for :CMakeCloseOverlay.
"
function! cmake#CloseOverlay() abort
    call s:logger.LogDebug('API invoked: cmake#CloseOverlay()')
    call s:terminal.CloseOverlay()
endfunction

" API function for third-party plugins to query information.
"
" Returns:
"     Dictionary
"         version : String
"             Vim-CMake version
"         status : String
"             current CMake status (e.g. Building...)
"         config : String
"             name of the set CMake configuration
"         cmake_version : Dictionary
"             major : Number
"                 CMake major version
"             minor : Number
"                 CMake minor version
"             patch : Number
"                 CMake patch version
"             string : String
"                 CMake version in string representation
"         project_dir : String
"             absolute path to detected project root (see g:cmake_root_markers)
"         build_dir : String
"             absolute path to the build directory for the set configuration
"
function! cmake#GetInfo() abort
    let info = {}
    let info.version = s:const.plugin_version
    let info.status = s:terminal.GetCmdInfo()
    let info.config = s:buildsys.GetCurrentConfig()
    let info.cmake_version = s:buildsys.GetCMakeVersion()
    let info.project_dir = s:buildsys.GetSourceDir()
    let info.build_dir = s:buildsys.GetPathToCurrentConfig()
    return info
endfunction
