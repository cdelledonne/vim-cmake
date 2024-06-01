" ==============================================================================
" Location:    autoload/cmake/buildsys.vim
" Description: Functions for generating the buildsystem
" ==============================================================================

let s:buildsys = {}
let s:buildsys.cmake_version = {'major': 0, 'minor': 0, 'patch': 0, 'string': ''}
let s:buildsys.project_root = ''
let s:buildsys.current_config = ''
let s:buildsys.path_to_current_config = ''
let s:buildsys.configs = []
let s:buildsys.tests = []

let s:refresh_tests_output = []

let s:const = cmake#const#Get()
let s:fileapi = cmake#fileapi#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:error = libs#error#Get(s:const.plugin_name, s:logger)
let s:state = libs#state#Get()
let s:statusline = cmake#statusline#Get()
let s:system = libs#system#Get()
let s:terminal = cmake#terminal#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:GetCMakeVersionCb(...) abort
    let lines = s:system.ExtractStdoutCallbackData(a:000).full_lines
    let index = match(lines, '\m\C^cmake\S* version')
    if index != -1
        let version_str = split(lines[index])[2]
        let version_parts = split(version_str, '\.')
        let s:cmake_version.major = str2nr(version_parts[0])
        let s:cmake_version.minor = str2nr(version_parts[1])
        let s:cmake_version.patch = str2nr(version_parts[2])
        let s:cmake_version.string = version_str
        call s:fileapi.CheckCMakeVersion(s:cmake_version)
    endif
endfunction

" Get CMake version.
"
" Returns:
"     Dictionary
"         the version is returned as a dictionary containing the keys major,
"         minor and patch (e.g., version 3.13.3 would result in the dict
"         {'major': 3, 'minor': 13, 'patch': 3, 'string': '3.13.3'})
"
function! s:GetCMakeVersion() abort
    let s:cmake_version = {}
    let command = [g:cmake_command, '--version']
    call s:system.JobRun(
        \ command, v:true, {'stdout_cb': function('s:GetCMakeVersionCb')})
    return s:cmake_version
endfunction

function! s:FindGitRootCb(...) abort
    let lines = s:system.ExtractStdoutCallbackData(a:000).full_lines
    for line in lines
        if isdirectory(line)
            let s:git_root = line
            break
        endif
    endfor
endfunction

" Find project root using git commands.
"
" Returns:
"     String
"         path to the root of the project, or empty string if nothing is found
"
function! s:FindGitRoot() abort
    let s:git_root = ''
    " Use `git rev-parse --show-superproject-working-tree` to look for git root,
    " assuming we're in a git submodule. If we are actually in a git submodule,
    " this will result in the path to the root repo.
    let command = ['git', 'rev-parse', '--show-superproject-working-tree']
    call s:system.JobRun(
        \ command, v:true, {'stdout_cb': function('s:FindGitRootCb')})
    if s:git_root !=# ''
        return s:git_root
    endif
    " Use `git rev-parse --show-toplevel` to look for git root, assuming we're
    " in a git repo but not in a submodule. If we are actually in a git repo,
    " this will result in the path to the repo.
    " Note: if invoked from a git submodule, this command returns the path to
    " the submodule, not the path to the root repo, this is why this needs to be
    " invoked only after `git rev-parse --show-superproject-working-tree`.
    let command = ['git', 'rev-parse', '--show-toplevel']
    call s:system.JobRun(
        \ command, v:true, {'stdout_cb': function('s:FindGitRootCb')})
    if s:git_root !=# ''
        return s:git_root
    endif
    " If we're not in a git repo at all, return an empty string.
    return ''
endfunction

" Find project root by looking for g:cmake_root_markers upwards.
"
" Returns:
"     String
"         escaped path to the root of the project
"
function! s:FindProjectRoot() abort
    " If '.git' is one of the root markers, try to use git commands to obtain
    " the root of the project.
    let match_res = match(g:cmake_root_markers, '\m\C^\.git$')
    if match_res != -1
        let root = s:FindGitRoot()
        if root !=# ''
            return root
        endif
    endif
    " Otherwise, search for root markers manually.
    let root = getcwd()
    let escaped_cwd = fnameescape(getcwd())
    for marker in g:cmake_root_markers
        " Search CWD upward for marker, assuming it is a file.
        let marker_path = findfile(marker, escaped_cwd . ';' . $HOME)
        if len(marker_path) > 0
            " If found, strip marker from it.
            let root = fnamemodify(marker_path, ':h')
            break
        endif
        " Search CWD upward for marker, assuming it is a directory.
        let marker_path = finddir(marker, escaped_cwd . ';' . $HOME)
        if len(marker_path) > 0
            " If found, strip marker from it.
            let root = fnamemodify(marker_path, ':h')
            break
        endif
    endfor
    return root
endfunction

" Get absolute path to location where the build directory is located.
"
" Returns:
"     String
"         path to build directory location
"
function! s:GetBuildDirLocation() abort
    return s:system.Path(
        \ [s:buildsys.project_root, g:cmake_build_dir_location], v:false)
endfunction

" Find CMake variable in list of options.
"
" Params:
"     opts : List
"         list of options
"     variable : String
"         variable to find
"
" Returns:
"     String
"         value of the CMake variable, or an empty string if the variable was
"         not found
"
" Example:
"     to find the variable 'CMAKE_BUILD_TYPE', which would be passed by the user
"     as '-D CMAKE_BUILD_TYPE=<value>', call
"             s:FindVarInOpts(opts, 'CMAKE_BUILD_TYPE')
"
function! s:FindVarInOpts(opts, variable) abort
    if len(a:opts) > 0
        " Search the list of command-line options for an entry matching
        " '-D <variable>=<value>' or '-D <variable>:<type>=<value>' or
        " '-D<variable>=<value>' or '-D<variable>:<type>=<value>'.
        let opt = matchstr(a:opts, '\m\C-D\s*' . a:variable)
        " If found, return the value, otherwise return an empty string.
        if len(opt) > 0
            return split(opt, '=')[1]
        else
            return ''
        endif
    endif
endfunction

" Process build configuration.
"
" Params:
"     opts : List
"         list of options
"
function! s:ProcessBuildConfig(opts) abort
    let config = s:buildsys.current_config
    " Check if the first entry of the list of command-line options starts with a
    " letter (and not with a dash), in which case the user will have passed the
    " name of the build configuration as the first option.
    if (len(a:opts) > 0) && (match(a:opts[0], '\m\C^\w') >= 0)
        " Update build config name and remove from list of options.
        let config = a:opts[0]
        call s:SetCurrentConfig(config)
        call remove(a:opts, 0)
    endif
    " If the build configuration does not exist yet, and the list of
    " command-line options does not contain an explicit value for the
    " 'CMAKE_BUILD_TYPE' variable, add it.
    if match(s:buildsys.configs, '\m\C' . config) == -1
        if s:FindVarInOpts(a:opts, 'CMAKE_BUILD_TYPE') ==# ''
            call add(a:opts, '-D CMAKE_BUILD_TYPE=' . config)
        endif
    endif
endfunction

" Get list of command-line options from string of arguments.
"
" Params:
"     args : List
"         command-line arguments
"
" Returns:
"     List
"         list of unprocessed command-line options
"
" Example:
"     an argument string like the following
"         'Debug -D VAR_A=1 -DVAR_B=0 -Wdev -U VAR_C'
"     results in a list of options like the following
"         ['Debug', '-D VAR_A=1', '-DVAR_B=0', '-Wdev', '-U VAR_C']
"
function! s:ArgsToOptList(args) abort
    let opts = []
    for arg in a:args
        " If list of options is empty, append first argument.
        if len(opts) == 0
            call add(opts, arg)
        " If argument starts with a dash, append it to the list of options.
        elseif match(arg, '\m\C^-') >= 0
            call add(opts, arg)
        " If argument does not start with a dash, it must belong to the last
        " option that was added to the list, thus extend that option.
        else
            let opts[-1] = join([opts[-1], arg])
        endif
    endfor
    return opts
endfunction

" Process string of arguments and return parsed options.
"
" Params:
"     args : List
"         command-line arguments
"
" Returns:
"     Dictionary
"         opts : List
"             list of options
"         source_dir : String
"             path to source directory
"         build_dir : String
"             path to build directory
"
function! s:ProcessArgString(args) abort
    let opts = s:ArgsToOptList(a:args)
    call s:ProcessBuildConfig(opts)
    " If compile commands are to be exported, and the
    " 'CMAKE_EXPORT_COMPILE_COMMANDS' variable is not set, set it.
    if g:cmake_link_compile_commands
        if s:FindVarInOpts(opts, 'CMAKE_EXPORT_COMPILE_COMMANDS') ==# ''
            call add(opts, '-D CMAKE_EXPORT_COMPILE_COMMANDS=ON')
        endif
    endif
    " Set source and build directories. Must be done after processing the build
    " configuration so that the current build configuration is up to date before
    " setting the build directory.
    let source_dir = s:system.Path([s:buildsys.project_root], v:true)
    let build_dir = s:system.Path([s:buildsys.path_to_current_config], v:true)
    " Return dictionary of options.
    let optdict = {}
    let optdict.opts = opts
    let optdict.source_dir = source_dir
    let optdict.build_dir = build_dir
    return optdict
endfunction

" Refresh list of build configuration directories.
"
function! s:RefreshConfigs() abort
    " List of directories inside of which a CMakeCache file is found.
    let cache_dirs = findfile(
        \ 'CMakeCache.txt',
        \ s:GetBuildDirLocation() . '/**1',
        \ -1)
    " Transform paths to just names of directories. These will be the names of
    " existing configuration directories.
    call map(cache_dirs, {_, val -> fnamemodify(val, ':h:t')})
    let s:buildsys.configs = cache_dirs
    call s:logger.LogDebug('Build configs: %s', s:buildsys.configs)
endfunction

" Refresh list of available CMake build targets.
"
function! s:RefreshTargets() abort
    try
        call s:fileapi.Parse(s:buildsys.path_to_current_config)
    catch
    endtry
endfunction

" Callback for RefreshTests().
"
function! s:RefreshTestsCb(...) abort
    let lines = s:system.ExtractStdoutCallbackData(a:000).full_lines
    call extend(s:refresh_tests_output, lines)
endfunction

" Refresh list of available CTest tests.
"
function! s:RefreshTests() abort
    let s:refresh_tests_output = []
    let s:buildsys.tests = []
    let build_dir = s:buildsys.path_to_current_config
    let command = [
        \ g:cmake_test_command,
        \ '--show-only=json-v1',
        \ '--test-dir', build_dir
    \ ]
    call s:system.JobRun(
        \ command, v:true, {'stdout_cb': function('s:RefreshTestsCb')})
    " Make list of tests from JSON data.
    let s:tests_data_json = json_decode(join(s:refresh_tests_output))
    let s:tests_data_list = s:tests_data_json.tests
    for s:test in s:tests_data_list
        call add(s:buildsys.tests, s:test.name)
    endfor
endfunction

" Check if build configuration directory exists.
"
" Params:
"     config : String
"         configuration to check
"
" Returns:
"     Boolean
"         v:true if the build configuration exists, v:false otherwise
"
function! s:ConfigExists(config) abort
    return index(s:buildsys.configs, a:config) >= 0
endfunction

" Set current build configuration.
"
" Params:
"     config : String
"         build configuration name
"
function! s:SetCurrentConfig(config) abort
    let s:buildsys.current_config = a:config
    let path = s:system.Path([s:GetBuildDirLocation(), a:config], v:false)
    let s:buildsys.path_to_current_config = path
    call s:logger.LogInfo('Current config: %s (%s)',
        \ s:buildsys.current_config,
        \ s:buildsys.path_to_current_config)
    " Save project's current config and build dir.
    let state = {}
    let state.config = a:config
    let state.build_dir = path
    call s:state.WriteProjectState(
        \ s:const.plugin_name, s:buildsys.project_root, state)
endfunction

" Link compile commands from source directory to build directory.
"
function! s:LinkCompileCommands() abort
    if !g:cmake_link_compile_commands
        return
    endif
    let target = s:system.Path(
        \ [s:buildsys.path_to_current_config, 'compile_commands.json'],
        \ v:true
        \ )
    let link = s:system.Path(
        \ [s:buildsys.project_root, 'compile_commands.json'],
        \ v:true,
        \ )
    let command = [g:cmake_command, '-E', 'create_symlink', target, link]
    call s:system.JobRun(command, v:true, {})
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Initialize project variables.
"
function! s:buildsys.Init() abort
    " Must be done before any other initial configuration.
    let s:buildsys.project_root = s:system.Path([s:FindProjectRoot()], v:false)
    call s:logger.LogInfo('Project root: %s', s:buildsys.project_root)

    if g:cmake_restore_state
        call s:SetCurrentConfig(get(
            \ s:state.ReadProjectState(
            \     s:const.plugin_name, s:buildsys.project_root),
            \ 'config',
            \ g:cmake_default_config))
    else
        call s:SetCurrentConfig(g:cmake_default_config)
    endif

    call s:RefreshConfigs()
    call s:RefreshTargets()
endfunction

" Generate a buildsystem for the project using CMake.
"
" Params:
"     clean : Boolean
"         whether to clean before generating
"     args : List
"         build configuration and additional CMake options
"
function! s:buildsys.Generate(clean, args) abort
    call s:logger.LogDebug('Invoked: buildsys.Generate(%s, %s)',
        \ a:clean, string(a:args))
    let command = [g:cmake_command]
    let optdict = s:ProcessArgString(a:args)
    " Construct command.
    call extend(command, g:cmake_generate_options)
    call extend(command, optdict.opts)
    let cmake_version_comparable =
        \ self.cmake_version.major * 100 + self.cmake_version.minor
    if cmake_version_comparable < 313
        call add(command, '-H' . optdict.source_dir)
        call add(command, '-B' . optdict.build_dir)
    else
        call add(command, '-S ' . optdict.source_dir)
        call add(command, '-B ' . optdict.build_dir)
    endif
    " Clean project buildsystem, if requested.
    if a:clean
        call self.Clean()
    endif
    call s:fileapi.UpdateQueries(optdict.build_dir)
    " Run generate command.
    let run_options = {}
    let run_options.callbacks_succ = [
        \ function('s:RefreshConfigs'),
        \ function('s:RefreshTargets'),
        \ function('s:RefreshTests'),
        \ function('s:LinkCompileCommands'),
    \ ]
    let run_options.callbacks_err = [function('s:RefreshConfigs')]
    let run_options.autocmds_pre = ['CMakeGeneratePre']
    call s:terminal.Run(command, 'GENERATE', run_options)
endfunction

" Clean buildsystem.
"
function! s:buildsys.Clean() abort
    call s:logger.LogDebug('Invoked: buildsys.Clean()')
    if isdirectory(self.path_to_current_config)
        call delete(self.path_to_current_config, 'rf')
    endif
    call s:RefreshConfigs()
    call s:fileapi.Reset()
endfunction

" Set current build configuration after checking that the configuration exists.
"
" Params:
"     config : String
"         build configuration name
"
function! s:buildsys.Switch(config) abort
    call s:logger.LogDebug('Invoked: buildsys.Switch(%s)', a:config)
    " Check that config exists.
    if !s:ConfigExists(a:config)
        call s:error.Throw('NO_CONFIG', a:config, a:config)
        return
    endif
    call s:SetCurrentConfig(a:config)
    call s:LinkCompileCommands()
    call s:RefreshTargets()
endfunction

" Run executable target after checking that the target exists.
"
" Params:
"     target : String
"         executable target name
"     args : List
"         program arguments
"
function! s:buildsys.Run(target, args) abort
    call s:logger.LogDebug('Invoked: buildsys.Run(%s)', a:target)
    call s:RefreshTargets()
    let exec_targets = s:fileapi.GetExecTargets()
    " Check that target exists.
    if !has_key(exec_targets, a:target)
        call s:error.Throw('NO_EXEC_TARGET', a:target)
        return
    endif
    " Also check that actual executable file exists.
    let exec_path = exec_targets[a:target]
    if !filereadable(exec_path)
        call s:error.Throw('NO_EXEC_PATH', exec_path)
        return
    endif
    if !executable(exec_path)
        call s:error.Throw('NOT_EXECUTABLE', exec_path)
        return
    endif
    " Run executable.
    let command = [exec_path] + a:args
    call s:terminal.RunOverlay(command)
endfunction

" Get list of configuration directories (containing a buildsystem).
"
" Returns:
"     List
"         list of existing configuration directories
"
function! s:buildsys.GetConfigs() abort
    return self.configs
endfunction

" Get list of available test names.
"
" Params:
"     refresh : Boolean
"         force refreshing list of tests
"
" Returns:
"     List
"         list of available test names
"
function! s:buildsys.GetTests(refresh) abort
    if len(self.tests) == 0 || a:refresh
        call s:RefreshTests()
    endif
    return self.tests
endfunction

" Get current build configuration.
"
" Returns:
"     String
"         build configuration
"
function! s:buildsys.GetCurrentConfig() abort
    return self.current_config
endfunction

" Get CMake version as dict
"
" Returns:
"     Dictionary
"         major : Number
"             cmake major version
"         minor : Number
"             cmake minor version
"         patch : Number
"             cmake patch version
"         string : String
"             cmake version in string representation
"
function! s:buildsys.GetCMakeVersion() abort
    return self.cmake_version
endfunction

" Get path to CMake source directory of current project.
"
" Returns:
"     String
"         path to CMake source directory
"
function! s:buildsys.GetSourceDir() abort
    return self.project_root
endfunction

" Get path to current build configuration.
"
" Returns:
"     String
"         path to build configuration
"
function! s:buildsys.GetPathToCurrentConfig() abort
    return self.path_to_current_config
endfunction

" Get buildsys 'object'.
"
function! cmake#buildsys#Get() abort
    return s:buildsys
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:buildsys.cmake_version = s:GetCMakeVersion()
