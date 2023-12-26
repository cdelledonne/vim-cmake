" ==============================================================================
" Location:    autoload/cmake/fileapi.vim
" Description: Functions for interfacing with the cmake-file-api(7)
" ==============================================================================

let s:fileapi = {}
let s:fileapi.cmake_version_supported = v:false
let s:fileapi.last_index_name = 'unset' " won't compare true
let s:fileapi.build_targets = []
let s:fileapi.exec_targets = {}

let s:client_name = 'vim-cmake'
let s:api_path = ['.cmake', 'api', 'v1']
let s:query_path = s:api_path + ['query', 'client-vim-cmake', 'query.json']
let s:reply_path = s:api_path + ['reply']

let s:query_version = 1
let s:query = {
    \ 'requests': [
    \     { 'kind': 'codemodel' , 'version': 2 },
    \ ],
    \ 'client': {
    \     'query': { 'version': s:query_version },
    \ },
    \ }

let s:const = cmake#const#Get()
let s:logger = libs#logger#Get(s:const.plugin_name)
let s:system = libs#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find the current response index file.
"
" Params:
"     build_dir : String
"         path to the build directory in which to look for api responses
"
" Returns:
"     String
"         path to response index file or empty string if none is found
"
function! s:FindIndexFile(build_dir) abort
    let glob = s:system.Path([a:build_dir] + s:reply_path + ['index'], v:false) . '-*.json'
    let indices = glob(glob, v:true, v:true)
    if len(indices) == 0
        return ''
    else
        return indices[-1]
    endif
endfunction

" Parse api response index.
"
" Params:
"     build_dir : String
"         path to the build directory in which to look for api responses
"
" Raises:
"     vim-cmake-fileapi-noindex:
"         no index file could be found
"     vim-cmake-fileapi-oldindex:
"         the found index file is for a different query version
"
" Returns:
"     Dictionary
"         mapping from query kind to corresponding response file path
"
function! s:ParseIndex(build_dir) abort
    let index_path = s:FindIndexFile(a:build_dir)
    if index_path ==# ''
        " TODO: only throw this with an existing build tree without api files
        " and when CMake version new enough
        throw 'vim-cmake-fileapi-noindex'
    elseif index_path ==# s:fileapi.last_index_name
        return v:null
    endif
    let s:fileapi.last_index_name = index_path

    let index = json_decode(join(readfile(index_path)))
    let reply = index.reply['client-' . s:client_name]['query.json']
    if reply.client.query.version != s:query_version
        throw 'vim-cmake-fileapi-oldindex'
    endif
    let response_files = {}
    " Update response references
    for response in reply.responses
        let path = [a:build_dir] + s:reply_path + [response.jsonFile]
        let response_files[response.kind] = s:system.Path(path, v:false)
    endfor
    return response_files
endfunction

" Parse codemodel api response.
"
" Params:
"     build_dir : String
"         path to the build directory in which to look for api responses
"     codemodel : String
"         the path to the codemodel response file
"
function! s:ParseCodemodel(build_dir, codemodel) abort
    let targets = {}
    " Parse codemodel file to find targets.
    let codemodel = json_decode(join(readfile(a:codemodel)))
    " Extract target name and executable path, if available, from target info
    for target in codemodel.configurations[0].targets
        let path_list = [a:build_dir] + s:reply_path + [target.jsonFile]
        let target_path = s:system.Path(path_list, v:false)
        let target_info = json_decode(join(readfile(target_path)))
        if target_info.type ==# 'EXECUTABLE'
            let targets[target.name] = s:system.Path(
                \ [a:build_dir, target_info.artifacts[0].path], v:true)
        else
            let targets[target.name] = ''
        endif
    endfor
    " Build targets is a list of all target names
    let s:fileapi.build_targets = keys(targets)
    " Executable targets is a dictionary of target names and executable paths -
    " a target is executable only if it has an executable path
    let s:fileapi.exec_targets = filter(targets, 'v:val !=# ""')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Check if CMake version is supported.
"
" Params:
"     cmake_version : Dictionary
"         major : Number
"             CMake major version
"         minor : Number
"             CMake minor version
"
" Returns:
"     Boolean
"         whether the passed CMake version is supported by fileapi
"
function! s:fileapi.CheckCMakeVersion(cmake_version) abort
    let cmake_version_comparable =
        \ a:cmake_version.major * 100 + a:cmake_version.minor
    let self.cmake_version_supported = cmake_version_comparable >= 314
    if !self.cmake_version_supported
        call s:logger.EchoWarn(s:const.errors['FILEAPI_VERSION'])
        call s:logger.LogWarn(s:const.errors['FILEAPI_VERSION'])
    endif

    return self.cmake_version_supported
endfunction

" Reset all fileapi state.
"
function! s:fileapi.Reset() abort
    let self.last_index_name = 'unset' " won't compare true
    let self.build_targets = []
    let self.exec_targets = {}
endfunction

" Set or update the query file.
"
" Params:
"     build_dir : String
"         path to current build configuration
"
function! s:fileapi.UpdateQueries(build_dir) abort
    let query_path = s:system.Path([a:build_dir] + s:query_path, v:false)
    " FIX: this creates the build_dir and queries even if not in a CMake project
    call mkdir(fnamemodify(query_path, ':h'), 'p')
    call writefile([json_encode(s:query)], query_path)
endfunction

" Parse the CMake responses if necessary.
"
" Params:
"     build_dir : String
"         path to current build configuration
"
" Raises:
"     vim-cmake-fileapi-noindex:
"         no index file could be found
"
function! s:fileapi.Parse(build_dir) abort
    if !self.cmake_version_supported
        return
    endif

    let response_files = v:null
    try
        let response_files = s:ParseIndex(a:build_dir)
    catch /vim-cmake-fileapi-oldindex/
        " TODO: Regenerate to update queries or bail
        " bail for now
        call s:logger.EchoWarn(s:const.errors['FILEAPI_RERUN'])
        call s:logger.LogWarn(s:const.errors['FILEAPI_RERUN'])
    endtry

    if response_files isnot v:null
        call s:ParseCodemodel(a:build_dir, response_files.codemodel)
    endif
endfunction

" Get List of CMake build target names.
"
" Returns:
"     List
"         CMake build target names
"
function! s:fileapi.GetBuildTargets() abort
    return self.build_targets
endfunction

" Get List of executable targets.
"
" Returns:
"     Dictionary
"         executable targets, a dictionary of {name, path} pairs
"
function! s:fileapi.GetExecTargets() abort
    return self.exec_targets
endfunction

" Get fileapi 'object'.
"
function! cmake#fileapi#Get() abort
    return s:fileapi
endfunction
