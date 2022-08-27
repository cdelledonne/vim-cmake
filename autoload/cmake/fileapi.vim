" ==============================================================================
" Location:    autoload/cmake/cmake-api.vim
" Description: Functions for interfacing with the cmake-fila-api(7)
" ==============================================================================

let s:fileapi = {}

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
    let l:glob = s:system.Path([a:build_dir] + s:reply_path + ['index'], v:true) . '-*.json'
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
    elseif l:index_path ==# s:fileapi.lastIndexName
        return 2
    endif
    let s:fileapi.lastIndexName = l:index_path

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
    let l:responses = {}
    for l:response in l:reply.responses
        let l:path = [a:build_dir] + s:reply_path + [l:response.jsonFile]
        let l:responses[l:response.kind] = s:system.Path(l:path, v:true)
    endfor
    let s:fileapi.version = l:reply.client.query.version
    let s:fileapi.index.responses = l:responses
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
    let l:path_list = [a:build_dir] + s:reply_path + [s:fileapi.index.responses.codemodel]
    let l:codemodel_path = s:system.Path(l:path_list, v:true)
    let l:codemodel = json_decode(join(readfile(s:fileapi.index.responses.codemodel)))
    call map(l:codemodel.configurations[0].targets, {_, val -> val.name})
    let s:fileapi.codemodel.targets = l:codemodel.configurations[0].targets
endfunction

" Check if CMake version is supported
"
function! s:AssertCMakeVersion() abort
    return v:true " FIXME: Actually check version
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Reset all fileapi state
"
function! s:fileapi.Reset() abort
    let s:fileapi.version = 0
    let s:fileapi.lastIndexName = 'unset' " won't compare true
    let s:fileapi.index = {}
    let s:fileapi.codemodel = {}
    let s:fileapi.codemodel.targets = []
endfunction

" Set or update the query file
"
" Params:
"     build_dir : String
"         path to current build configuration
"
function! s:fileapi.UpdateQueries(build_dir) abort
    let l:query_path = s:system.Path([a:build_dir] + s:query_path, v:true)
    call mkdir(fnamemodify(l:query_path, ':h'), 'p')
    call writefile([json_encode(s:query)], l:query_path)
endf

" Reparse the cmake responses if necessary
"
" Params:
"     build_dir : String
"         path to current build configuration
"
function! s:fileapi.Reparse(build_dir) abort
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
    return s:fileapi.codemodel.targets
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
