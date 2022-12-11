" Associated vim plugin of unitex.
" Maintainer: Juiyung Hsu
" License: Vim license (see vim's :help license)

if &cp || exists('g:loaded_unitex')
  finish
endif
let g:loaded_unitex = 'v1'

com! -nargs=1 Unitex call s:Unitex(<q-args>)

func s:Unitex(arg)
  if a:arg ==? 'on'
    call unitex#on(bufnr('%'))
  elseif a:arg ==? 'off'
    call unitex#off(bufnr('%'))
  else
    echohl ErrorMsg
    echomsg "**error** (Unitex): invalid argument '" . a:arg . "'"
    echohl NONE
  endif
endfunc

imap <Plug>(unitex-peek) <Cmd>call unitex#peek()<CR>
nmap <Plug>(unitex-peek) <Cmd>call unitex#peek()<CR>
