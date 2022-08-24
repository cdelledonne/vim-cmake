" ==============================================================================
" Location:    autoload/cmake/state.vim
" Description: Functions for writing and reading Vim-CMake's state
" ==============================================================================

let s:state = {}

let s:state_file_name = 'state.json'

let s:system = cmake#system#Get()

" Read Vim-CMake global state from disk.
"
" Returns:
"     Dictionary
"         global state
"
function! s:state.ReadGlobalState() abort
    let l:data_dir = s:system.GetDataDir()
    let l:state_file = s:system.Path([l:data_dir, s:state_file_name], v:false)
    " Try to read JSON state file, otherwise return empty dict.
    let l:state = {}
    try
        let l:state_data = join(readfile(l:state_file))
        let l:state = json_decode(l:state_data)
    catch
    endtry
    return l:state
endfunction

" Read Vim-CMake project-specific state from disk.
"
" Params:
"     project : String
"         project path to read state for
"
" Returns:
"     Dictionary
"         project-specific state
"
function! s:state.ReadProjectState(project) abort
    " Global state is of the form {..., 'projects', {p1: {...}, p2: {...}}}.
    let l:global_state = l:self.ReadGlobalState()
    let l:projects = get(l:global_state, 'projects', {})
    let l:project_state = get(l:projects, a:project, {})
    return l:project_state
endfunction

" Write Vim-CMake global state to disk.
"
" Params:
"     state : Dictionary
"         global state to write
"
function! s:state.WriteGlobalState(state) abort
    let l:data_dir = s:system.GetDataDir()
    let l:state_file = s:system.Path([l:data_dir, s:state_file_name], v:false)
    let l:global_state = l:self.ReadGlobalState()
    " Update the global state to include the new state.
    call extend(l:global_state, a:state, 'force')
    try
        call mkdir(l:data_dir, 'p')
        call writefile([json_encode(l:global_state)], l:state_file)
    catch
    endtry
endfunction

" Write Vim-CMake project-specific state to disk.
"
" Params:
"     project : String
"         project path to write state for
"     state : Dictionary
"         project-specific state to write
"
function! s:state.WriteProjectState(project, state) abort
    let l:data_dir = s:system.GetDataDir()
    let l:state_file = s:system.Path([l:data_dir, s:state_file_name], v:false)
    let l:global_state = l:self.ReadGlobalState()
    let l:project_state = l:self.ReadProjectState(a:project)
    " Add state passed as argument to the (possibly not existing) project state.
    call extend(l:project_state, a:state, 'force')
    " Update the global state to include the new project state.
    if !has_key(l:global_state, 'projects')
        let l:global_state.projects = {}
    endif
    let l:global_state.projects[a:project] = l:project_state
    try
        call mkdir(l:data_dir, 'p')
        call writefile([json_encode(l:global_state)], l:state_file)
    catch
    endtry
endfunction

" Get state 'object'.
"
function! cmake#state#Get() abort
    return s:state
endfunction
