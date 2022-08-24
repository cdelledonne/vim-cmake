" ==============================================================================
" Location:    autoload/cmake/cmake-api.vim
" Description: Functions for interfacing with the cmake-fila-api(7)
" ==============================================================================

let s:fileapi = {}
let s:fileapi.version = 0
let s:fileapi.index = {}
let s:fileapi.codemodel = {}
let s:fileapi.codemodel.targets = []

let s:logger = cmake#logger#Get()
let s:system = cmake#system#Get()

let s:build_dir = ''

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
            \         'query': { 'version': s:query_version }
            \     }
            \ }

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find the current index file
"
function! s:FindIndexFile() abort
    let l:glob = s:system.Path([s:build_dir] + s:reply_path + ['index'], v:true) . '-*.json'
    let l:indices = glob(l:glob, v:true, v:true)
    if len(l:indices) == 0
        throw 0
    else
        return l:indices[-1]
    endif
endfunction

" Parse api response index
"
function! s:ParseIndex() abort
    let l:index_path = s:FindIndexFile()
    let l:index = json_decode(readfile(l:index_path))
    let l:reply = l:index.reply['client-' . s:client_name]['query.json']
    if l:reply.client.query.version != s:query_version
        " TODO: Regenerate to update queries or bail
        " bail for now 
        call s:logger.EchoError('Api query out of date, run :CMakeGenerate')
        call s:logger.LogError('Api query out of date, run :CMakeGenerate')
        throw 1
    endif
    " Update response references
    let l:responses = {}
    for response in l:reply.responses
        let l:responses[response.kind] = s:system.Path([s:build_dir] + s:reply_path + [response.jsonFile], v:true)
    endfor
    " set state
    let s:fileapi.version = l:reply.client.query.version
    let s:fileapi.index.responses = l:responses
endfunction

function! s:ParseCodemodel() abort
    if empty(s:fileapi.index) || s:fileapi.version != s:query_version
        call s:ParseIndex()
    endif
    let l:codemodel_path = s:system.Path([s:build_dir] + s:reply_path + [s:fileapi.index.responses.codemodel], v:true)
    let l:codemodel = json_decode(join(readfile(s:fileapi.index.responses.codemodel)))
    let s:fileapi.codemodel.targets = map(copy(l:codemodel.configurations[0].targets), 'v:val.name')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:fileapi.UpdateQueries(build_dir) abort
    try
        let s:build_dir = a:build_dir
        let l:query_path = s:system.Path(extend([s:build_dir], s:query_path), v:true)
        call mkdir(fnamemodify(l:query_path, ':h'), 'p')
        call writefile([json_encode(s:query)], l:query_path)
    catch
    endtry
endf

fun! s:fileapi.Reparse(build_dir) abort
    let s:build_dir = a:build_dir
    call s:ParseCodemodel()
endf

function! s:fileapi.GetTargets() abort
    return s:fileapi.codemodel.targets
endfunction

" Get fileapi 'object'.
"
function! cmake#fileapi#Get() abort
    return s:fileapi
endfunction
