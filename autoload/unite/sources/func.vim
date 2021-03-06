let s:save_cpo = &cpo
set cpo&vim

call unite#util#set_default('g:unite_source_func_search_word_highlight', 'Search')

if !executable('parsefunc')
  echohl WarningMsg | echon 'Command parsefunc not found, please run `npm install pasrsefunc` first!' | echohl None
  finish
endif

let s:source = {
      \ 'name': 'func',
      \ 'hooks': {},
      \ 'action_table': {'*': {}},
      \ 'syntax' : 'uniteSource__Grep',
      \ 'matchers' : 'matcher_regexp',
      \ }

function! s:source.hooks.on_init(args, context) abort
  "let a:context.source__input = get(a:args, 2, a:context.input)
  let a:context.source__input = len(a:context.input) == 0 ? ' ' : a:context.input
  call s:resolvaRoot()
endfunction

function! s:source.hooks.on_syntax(args, context) abort
  syntax case ignore
  syntax match uniteSource__GrepHeader /[^:]*: \d\+: \(\d\+: \)\?/ contained
        \ containedin=uniteSource__Grep
  syntax match uniteSource__GrepFile /[^:]*: / contained
        \ containedin=uniteSource__GrepHeader
        \ nextgroup=uniteSource__GrepLineNR
  syntax match uniteSource__GrepLineNR /\s*\d\+: / contained
        \ containedin=uniteSource__GrepHeader
        \ nextgroup=uniteSource__GrepPattern
  syntax match uniteSource__GrepSeparator /:/ contained conceal
        \ containedin=uniteSource__GrepFile,uniteSource__GrepLineNR
  highlight default link uniteSource__GrepFile Comment
  highlight default link uniteSource__GrepLineNr LineNR
  execute 'highlight default link uniteSource__GrepPattern'
        \ get(a:context, 'custom_func_search_word_highlight',
        \ g:unite_source_func_search_word_highlight)
endfunction

function! s:source.hooks.on_close(args, context) abort
endfunction

function! s:format(list) abort
  if len(a:list) == 1
    return printf("%s", a:list[0])
  endif
  let path = a:list[0]
  if path =~# 'node_modules'
    let path = split(path, 'node_modules\/')[-1]
  endif
  if path ==? 'stdin'
    let path = expand('%')
  endif
  let linenr = a:list[1]
  let text = len(a:list[2]) ? a:list[2] : ' '
  return printf("%s: %s: %s", path, linenr, split(text,'\.')[-1])
endfunction

function! s:source.gather_candidates(args, context) abort
  let type = get(a:context, 'custom_func_type', '')
  if type ==# 't'
    let opts = '-m this'
  elseif type ==# 'm'
    let name = get(a:context, 'custom_func_name', '')
    if len(name)
      let opts = '-m '.name
    else
      let opts = '-a'
    endif
  elseif type ==# 'r'
    let opts = '-r '.fnameescape(expand('%'))
  elseif type ==# 'e'
    let opts = '-m ' . expand('%')
  else
    let opts = expand('%')
  endif
  let opts .= ' -e ' . &encoding

  if !len(type)
    let lines = getline(1, '$')
    let res = system("parsefunc", lines)
    let list = map(split(res, '\n'), 'split(v:val, ":")')
  else
    let res = system("parsefunc " . opts)
    let list = map(split(res, '\n'), 'split(v:val, ":")')
  endif

  if v:shell_error
      call unite#print_source_error(res, s:source.name)
      return []
  endif

  " "action__type" is necessary to avoid being added into cmdline-history.
  return map(list, '{
        \ "word": s:format(v:val),
        \ "source": "func",
        \ "kind": ["file", "jump_list"],
        \ "action__text": s:format(v:val),
        \ "action__line": len(v:val) > 1 ? v:val[1] : 0,
        \ "action__path": s:path(v:val[0]),
        \ "action__directory": fnamemodify(v:val[0], ":h"),
        \ }')
endfunction

" lcd to project root if root not in current cwd
function! s:resolvaRoot() abort
  let file = findfile('package.json', ".;")
  if !len(file) | return | endif
  let dir = fnamemodify(file, ':h')
  let cwd = getcwd()
  if cwd !~ dir
    execute 'lcd ' . dir
  endif
endfunction

function! s:path(str) abort
  let p = a:str ==# 'stdin' ? expand('%') : a:str
  return unite#util#substitute_path_separator(fnamemodify(p, ':p'))
endfunction

function! s:basename(str) abort
  return split('.'.a:str, '\.')[-1]
endfunction

function! unite#sources#func#define() abort
  return s:source
endfunction

"unlet s:source

let &cpo = s:save_cpo
unlet s:save_cpo
