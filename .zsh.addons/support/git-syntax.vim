" Trusted adapter for Apple's system Vim. Input is captured source in stdin;
" output is numeric token metadata, never ANSI or code. No repository files,
" user vimrc, modelines, plugins, filetype detection, shada/viminfo or swap.
set encoding=utf-8 nomodeline noexrc noswapfile noundofile
set packpath= synmaxcol=8192
if $VIMRUNTIME !~# '^/usr/share/vim/vim[0-9]\+$'
  cquit
endif
let &runtimepath = $VIMRUNTIME
let s:input = readfile('/dev/stdin')
let s:language = remove(s:input, 0)
if index(['swift', 'zsh', 'sh', 'json', 'python'], s:language) < 0
  cquit
endif
let s:started = reltime()
let s:output = ['compozsh-syntax-1']
let s:roles = {'Statement': 'keyword', 'Conditional': 'keyword', 'Repeat': 'keyword',
      \ 'Keyword': 'keyword', 'Exception': 'keyword', 'Label': 'keyword',
      \ 'PreProc': 'keyword', 'Include': 'keyword', 'Define': 'keyword',
      \ 'Macro': 'keyword', 'PreCondit': 'keyword', 'String': 'string',
      \ 'Character': 'string', 'Constant': 'number', 'Number': 'number',
      \ 'Float': 'number', 'Boolean': 'number', 'Comment': 'comment',
      \ 'Type': 'type', 'StorageClass': 'type', 'Structure': 'type',
      \ 'Typedef': 'type', 'Function': 'function', 'Identifier': 'variable'}

function! s:Emit(row, start, end, role) abort
  if a:role !=# ''
    call add(s:output, printf('%d %d %d %s', a:row, a:start, a:end, a:role))
    if len(s:output) > 4097 | throw 'token limit' | endif
  endif
endfunction

function! s:Analyze(lines, rows) abort
  if empty(a:lines) | return | endif
  enew!
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nomodeline
  call setline(1, a:lines)
  syntax clear
  unlet! b:current_syntax
  execute 'source ' . fnameescape($VIMRUNTIME . '/syntax/' . s:language . '.vim')
  syntax sync fromstart
  for lnum in range(1, len(a:lines))
    if reltimefloat(reltime(s:started)) > 0.22 | throw 'time limit' | endif
    " Analyze forward for Vim's syntax cache. Suppressed context on the old
    " side still establishes comment/string state for subsequent deletions.
    let byte = 1 | let character = 0 | let start = 0 | let previous = ''
    for char in split(a:lines[lnum - 1], '\zs')
      let group = synIDattr(synIDtrans(synID(lnum, byte, 1)), 'name')
      let role = get(s:roles, group, '')
      if role !=# previous
        if a:rows[lnum - 1] > 0 | call s:Emit(a:rows[lnum - 1], start, character, previous) | endif
        let start = character | let previous = role
      endif
      let byte += strlen(char) | let character += 1
    endfor
    if a:rows[lnum - 1] > 0 | call s:Emit(a:rows[lnum - 1], start, character, previous) | endif
  endfor
endfunction

try
  " Consecutive source coordinates form one lexical fragment. Never join
  " distant hunks or mix the pre-change and post-change languages' states.
  for side in [1, 2]
    let lines = [] | let rows = [] | let previous = 0
    for record in s:input
      if empty(record) | continue | endif
      let parts = matchlist(record, '^\([0-9]\+\)\t\([0-9]\+\)\t\([0-9]\+\)\t\(.*\)$')
      if empty(parts) | throw 'invalid input' | endif
      let coordinate = str2nr(parts[side + 1])
      if coordinate == 0 | continue | endif
      if previous && coordinate != previous + 1
        call s:Analyze(lines, rows)
        let lines = [] | let rows = []
      endif
      call add(lines, parts[4])
      call add(rows, side == 1 && str2nr(parts[3]) > 0 ? 0 : str2nr(parts[1]))
      let previous = coordinate
    endfor
    call s:Analyze(lines, rows)
  endfor
  call add(s:output, 'done')
  call writefile(s:output, '/dev/stdout', 'a')
catch
  cquit
endtry
qa!
