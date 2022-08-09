" ==============================================================================
" Location:    autoload/cmake/util.vim
" Description: Utility functions
" ==============================================================================

let s:logger = cmake#logger#Get()
let s:state = cmake#state#Get()
let s:system = cmake#system#Get()

let s:repo_dir = expand('<sfile>:p:h:h:h')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:VersionToNumber(_, version) abort
    let l:version = split(a:version, '\.')
    let l:major = str2nr(l:version[0])
    let l:minor = str2nr(l:version[1])
    let l:patch = str2nr(l:version[2])
    let l:number = l:major * 10000 + l:minor * 100 + l:patch
    return l:number
endfunction

function! s:NumberToVersion(number) abort
    let l:major = a:number / 10000
    let l:minor = (a:number - l:major * 10000) / 100
    let l:patch = a:number - l:major * 10000 - l:minor * 100
    let l:version = l:major . '.' . l:minor . '.' . l:patch
    return l:version
endfunction

function! s:UpdateVersionNumber(version) abort
    " Try to read previous version number from deprecated data file. If the
    " deprecated data file is found, write version number to state dict, and
    " then delete the deprecated data file and data directory.
    try
        let l:data_dir = s:system.Path([s:repo_dir, '.data'], v:false)
        let l:data_file = s:system.Path(
                \ [l:data_dir, 'previous-version.bin'], v:false)
        let l:previous_version = readfile(l:data_file, 'b')[0]
        call s:state.WriteGlobalState({'version': l:previous_version})
        call delete(l:data_file)
        call delete(l:data_dir, 'd')
    catch
    endtry
    " Read previous version number from state.
    let l:previous_version = get(s:state.ReadGlobalState(), 'version', '')
    " If version number is not present in state dict, write it.
    if l:previous_version ==# ''
        call s:state.WriteGlobalState({'version': a:version})
        let l:previous_version_number = s:VersionToNumber('', a:version)
    else
        " Get previous version number from state, then write current version.
        let l:previous_version_number = s:VersionToNumber('', l:previous_version)
        if l:previous_version_number < s:VersionToNumber('', a:version)
            call s:state.WriteGlobalState({'version': a:version})
        endif
    endif
    return l:previous_version_number
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Print news of newer Vim-CMake versions.
"
" Params:
"     current_version : String
"         current version of the plugin (in the format <major>.<minor>.<patch>)
"     news : Dictionary
"         dictionary of news, where a key identifies a version (in the format
"         <major>.<minor>.<patch>), and a value is a string containing the news
"         to print for a version
"
function! cmake#util#PrintNews(current_version, news) abort
    let l:previous_version_number = s:UpdateVersionNumber(a:current_version)
    let l:current_version_number = s:VersionToNumber('', a:current_version)
    if l:previous_version_number == l:current_version_number
        return
    endif
    " Make a list of all version numbers, transform to integers, and sort.
    let l:all_version_numbers = keys(a:news)
    call map(l:all_version_numbers, function('s:VersionToNumber'))
    call sort(l:all_version_numbers)
    " Print updates for newer versions.
    for l:number in l:all_version_numbers
        if l:number > l:previous_version_number
            for l:news_item in a:news[s:NumberToVersion(l:number)]
                call s:logger.EchoInfo(l:news_item)
            endfor
        endif
    endfor
endfunction
