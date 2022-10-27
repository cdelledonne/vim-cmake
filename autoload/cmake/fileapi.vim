" ==============================================================================
" Location:    autoload/cmake/fileapi.vim
" Description: Functions for interfacing with the cmake-file-api(7)
" ==============================================================================

let s:fileapi = {}
let s:fileapi.cmake_version_supported = v:false
let s:fileapi.last_index_name = 'unset' " won't compare true
let s:fileapi.response_files = {}
let s:fileapi.build_targets = []

let s:client_name = 'vim-cmake'
let s:api_path = ['.cmake', 'api', 'v1']
let s:query_path = s:api_path + ['query', 'client-vim-cmake', 'query.json']
let s:reply_path = s:api_path + ['reply']

let s:query_version = 1
let s:query = {
            \     'requests': [
            \         { 'kind': 'codemodel' , 'version': 2 },
            \     ],
            \     'client': {
            \         'query': { 'version': s:query_version },
            \     },
            \ }

let s:logger = cmake#logger#Get()
let s:system = cmake#system#Get()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find the current index file
"
function! s:FindIndexFile(build_dir) abort
    let l:glob = s:system.Path([a:build_dir] + s:reply_path + ['index'], v:false) . '-*.json'
    let l:indices = glob(l:glob, v:true, v:true)
    if len(l:indices) == 0
        return ''
    else
        return l:indices[-1]
    endif
endfunction

" Parse api response index
"
" Returns:
"     Number
"         0: Failed
"         1: Updated
"         2: No Update
"
function! s:ParseIndex(build_dir) abort
    let l:index_path = s:FindIndexFile(a:build_dir)
    if l:index_path ==# ''
        return 0
    elseif l:index_path ==# s:fileapi.last_index_name
        return 2
    endif
    let s:fileapi.last_index_name = l:index_path

    let l:index = json_decode(readfile(l:index_path))
    let l:reply = l:index.reply['client-' . s:client_name]['query.json']
    if l:reply.client.query.version != s:query_version
        " TODO: Regenerate to update queries or bail
        " bail for now 
        call s:logger.EchoError('Api query out of date, run :CMakeGenerate')
        call s:logger.LogError('Api query out of date, run :CMakeGenerate')
        return 0
    endif
    " Update response references
    for l:response in l:reply.responses
        let l:path = [a:build_dir] + s:reply_path + [l:response.jsonFile]
        let s:fileapi.response_files[l:response.kind] = s:system.Path(l:path, v:false)
    endfor
    return 1
endfunction

" Parse codemodel api response
"
" Returns:
"   Number
"       0: Failed
"       1: Updated
"
function! s:ParseCodemodel(build_dir) abort
    let l:codemodel = json_decode(join(readfile(s:fileapi.response_files.codemodel)))
    call map(l:codemodel.configurations[0].targets, {_, val -> val.name})
    let s:fileapi.build_targets = l:codemodel.configurations[0].targets
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Check if CMake version is supported
"
" Params:
"     cmake_version : Dictionary
"         major : Number
"             cmake major version
"         minor : Number
"             cmake minor version
"
" Returns:
"   Boolean
"       Whether passed cmake version is supported by fileapi
"
function! s:fileapi.CheckCMakeVersion(cmake_version) abort
    let l:cmake_version_comparable =
                \ a:cmake_version.major * 100 + a:cmake_version.minor
    let l:self.cmake_version_supported = l:cmake_version_comparable >= 314
    if !l:self.cmake_version_supported
        let l:warning =
                    \ 'fileapi: CMake version not supported.'
                    \ . ' Certain functionality will not work correctly.'
                    \ . ' (Minimum supported is CMake 3.14)'
        call s:logger.EchoWarn(l:warning)
        call s:logger.LogWarn(l:warning)
    endif

    return l:self.cmake_version_supported
endfunction

" Reset all fileapi state
"
function! s:fileapi.Reset() abort
    let l:self.last_index_name = 'unset' " won't compare true
    let l:self.response_files = {}
    let l:self.build_targets = []
endfunction

" Set or update the query file
"
" Params:
"     build_dir : String
"         path to current build configuration
"
function! s:fileapi.UpdateQueries(build_dir) abort
    let l:query_path = s:system.Path([a:build_dir] + s:query_path, v:false)
    call mkdir(fnamemodify(l:query_path, ':h'), 'p')
    call writefile([json_encode(s:query)], l:query_path)
endf

" Parse the cmake responses if necessary
"
" Params:
"     build_dir : String
"         path to current build configuration
"
function! s:fileapi.Parse(build_dir) abort
    if !l:self.cmake_version_supported
        return
    endif

    let l:ret = s:ParseIndex(a:build_dir)
    " We only have to reparse if the index file changed
    if l:ret == 1
        call s:ParseCodemodel(a:build_dir)
    endif
endfunction

" Get List of CMake target names
"
" Returns:
"     List
"         CMake target names
"
function! s:fileapi.GetTargets() abort
    return l:self.build_targets
endfunction

" Get fileapi 'object'.
"
function! cmake#fileapi#Get() abort
    return s:fileapi
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

call s:fileapi.Reset()
