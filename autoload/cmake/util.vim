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
    let major = str2nr(l:version[0])
    let minor = str2nr(l:version[1])
    let patch = str2nr(l:version[2])
    let number = major * 10000 + minor * 100 + patch
    return number
endfunction

function! s:NumberToVersion(number) abort
    let major = a:number / 10000
    let minor = (a:number - major * 10000) / 100
    let patch = a:number - major * 10000 - minor * 100
    let l:version = major . '.' . minor . '.' . patch
    return l:version
endfunction

function! s:UpdateVersionNumber(version) abort
    " Try to read previous version number from deprecated data file. If the
    " deprecated data file is found, write version number to state dict, and
    " then delete the deprecated data file and data directory.
    try
        let data_dir = s:system.Path([s:repo_dir, '.data'], v:false)
        let data_file = s:system.Path(
            \ [data_dir, 'previous-version.bin'], v:false)
        let previous_version = readfile(data_file, 'b')[0]
        call s:state.WriteGlobalState({'version': previous_version})
        call delete(data_file)
        call delete(data_dir, 'd')
    catch
    endtry
    " Read previous version number from state.
    let previous_version = get(s:state.ReadGlobalState(), 'version', '')
    " If version number is not present in state dict, write it.
    if previous_version ==# ''
        call s:state.WriteGlobalState({'version': a:version})
        let previous_version_number = s:VersionToNumber('', a:version)
    else
        " Get previous version number from state, then write current version.
        let previous_version_number = s:VersionToNumber('', previous_version)
        if previous_version_number < s:VersionToNumber('', a:version)
            call s:state.WriteGlobalState({'version': a:version})
        endif
    endif
    return previous_version_number
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
    let previous_version_number = s:UpdateVersionNumber(a:current_version)
    let current_version_number = s:VersionToNumber('', a:current_version)
    if previous_version_number == current_version_number
        return
    endif
    " Make a list of all version numbers, transform to integers, and sort.
    let all_version_numbers = keys(a:news)
    call map(all_version_numbers, function('s:VersionToNumber'))
    call sort(all_version_numbers)
    " Print updates for newer versions.
    for number in all_version_numbers
        if number > previous_version_number
            for news_item in a:news[s:NumberToVersion(number)]
                call s:logger.EchoInfo(news_item)
            endfor
        endif
    endfor
endfunction
