" Trusted adapter for Apple's system Vim. Input and output use private FIFOs
" owned by one Git review screen session. Output is
" numeric token metadata, never ANSI or code. No repository files, user vimrc,
" modelines, plugins, filetype detection, viminfo, swap or undo are used.
set encoding=utf-8 nomodeline noexrc noswapfile noundofile
set packpath= synmaxcol=8192
if $VIMRUNTIME !~# '^/usr/share/vim/vim[0-9]\+$'
  cquit
endif
let &runtimepath = $VIMRUNTIME

let s:allowed = ['swift', 'zsh', 'sh', 'json', 'python']
let s:buffers = {}
let s:roles = {'Statement': 'keyword', 'Conditional': 'keyword', 'Repeat': 'keyword',
      \ 'Keyword': 'keyword', 'Exception': 'keyword', 'Label': 'keyword',
      \ 'PreProc': 'keyword', 'Include': 'keyword', 'Define': 'keyword',
      \ 'Macro': 'keyword', 'PreCondit': 'keyword', 'String': 'string',
      \ 'Character': 'string', 'Constant': 'number', 'Number': 'number',
      \ 'Float': 'number', 'Boolean': 'number', 'Comment': 'comment',
      \ 'Type': 'type', 'StorageClass': 'type', 'Structure': 'type',
      \ 'Typedef': 'type', 'Function': 'function', 'Identifier': 'variable'}

function! s:Emit(output, row, start, end, role) abort
  if a:role !=# ''
    call add(a:output, printf('%d %d %d %s', a:row, a:start, a:end, a:role))
    if len(a:output) > 4097 | throw 'token limit' | endif
  endif
endfunction

" Retain one nofile buffer per audited language for this process. Syntax
" definitions are sourced once; every request replaces all captured text.
function! s:Install(language, lines) abort
  if has_key(s:buffers, a:language) && bufexists(s:buffers[a:language])
    execute 'buffer!' s:buffers[a:language]
    silent %delete _
  else
    enew!
    setlocal buftype=nofile bufhidden=hide nobuflisted noswapfile nomodeline
    syntax clear
    unlet! b:current_syntax
    execute 'source ' . fnameescape($VIMRUNTIME . '/syntax/' . a:language . '.vim')
    let s:buffers[a:language] = bufnr('%')
  endif
  call setline(1, empty(a:lines) ? [''] : a:lines)
  syntax sync fromstart
endfunction

function! s:Analyze(output, started, language, lines, rows) abort
  if empty(a:lines) | return | endif
  call s:Install(a:language, a:lines)
  for lnum in range(1, len(a:lines))
    " This is a child-side liveness guard, not an interaction budget. The Zsh
    " picker never waits for it and rejects stale request generations, so a
    " generous bound tolerates cold grammars and temporary CPU contention
    " without allowing a broken syntax script to live forever.
    if reltimefloat(reltime(a:started)) > 0.80 | throw 'time limit' | endif
    " Analyze forward for Vim's syntax cache. Suppressed context on the old
    " side still establishes comment/string state for subsequent deletions.
    let byte = 1 | let character = 0 | let start = 0 | let previous = ''
    for char in split(a:lines[lnum - 1], '\zs')
      let group = synIDattr(synIDtrans(synID(lnum, byte, 1)), 'name')
      let role = get(s:roles, group, '')
      if role !=# previous
        if a:rows[lnum - 1] > 0 | call s:Emit(a:output, a:rows[lnum - 1], start, character, previous) | endif
        let start = character | let previous = role
      endif
      let byte += strlen(char) | let character += 1
    endfor
    if a:rows[lnum - 1] > 0 | call s:Emit(a:output, a:rows[lnum - 1], start, character, previous) | endif
  endfor
endfunction

function! s:Tokenize(source) abort
  if empty(a:source) | throw 'missing language' | endif
  let input = copy(a:source)
  let language = remove(input, 0)
  if index(s:allowed, language) < 0 | throw 'unsupported language' | endif
  let started = reltime()
  let output = ['compozsh-syntax-1']
  " Consecutive source coordinates form one lexical fragment. Never join
  " distant hunks or mix the pre-change and post-change languages' states.
  for side in [1, 2]
    let lines = [] | let rows = [] | let previous = 0
    for record in input
      if empty(record) | continue | endif
      let parts = matchlist(record, '^\([0-9]\+\)\t\([0-9]\+\)\t\([0-9]\+\)\t\(.*\)$')
      if empty(parts) | throw 'invalid input' | endif
      let coordinate = str2nr(parts[side + 1])
      if coordinate == 0 | continue | endif
      if previous && coordinate != previous + 1
        call s:Analyze(output, started, language, lines, rows)
        let lines = [] | let rows = []
      endif
      call add(lines, parts[4])
      call add(rows, side == 1 && str2nr(parts[3]) > 0 ? 0 : str2nr(parts[1]))
      let previous = coordinate
    endfor
    call s:Analyze(output, started, language, lines, rows)
  endfor
  call add(output, 'done')
  return output
endfunction

" Session mode is a framed request/response loop over private FIFOs. The
" parent owns this process for one Git review screen session. A ready marker
" precedes each blocking read, and numeric IDs let the parent reject stale data.
function! s:Session() abort
  let request = $COMPOZSH_GIT_SYNTAX_REQUEST
  let response = $COMPOZSH_GIT_SYNTAX_RESPONSE
  if empty(request) || empty(response) | cquit | endif
  while 1
    call writefile(['compozsh-ready-1'], response)
    let input = readfile(request)
    if input ==# ['compozsh-quit-1'] | break | endif
    if empty(input) || input[0] !~# '^compozsh-request-1:[1-9][0-9]*$'
      continue
    endif
    let request_id = matchstr(remove(input, 0), '[1-9][0-9]*$')
    try
      let output = s:Tokenize(input)
    catch
      let output = ['compozsh-error-1']
    endtry
    call writefile(['compozsh-response-1:' . request_id] + output +
          \ ['compozsh-response-end-1:' . request_id], response)
  endwhile
endfunction

call s:Session()
qa!
