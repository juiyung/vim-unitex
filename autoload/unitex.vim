" Associated vim plugin of unitex.
" Maintainer: Juiyung Hsu
" License: Vim license (see vim's :help license)

let s:keep_cpo = &cpo
set cpo&vim

" command! -nargs=+ UnitexAssert
"       \ if !(<args>)
"       \|  if unitex#isjobrunning()
"       \|    call unitex#stopjob()
"       \|  endif
"       \|  throw 'Assertion failed: ' . <q-args>
"       \|endif

func s:echoerr(msg)
  echohl ErrorMsg | echomsg '**error**' a:msg | echohl NONE
endfunc

func s:refbuf(bufnr)
  return a:bufnr == bufnr('%')? 'current buffer': 'buffer ' . a:bufnr
endfunc

let g:unitex#buffers = []
let g:unitex#job = v:none

func unitex#startjob()
  " UnitexAssert g:unitex#job is v:none
  let g:unitex#job = job_start('unitex', {'err_cb': 'unitex#joberrcb', 'exit_cb': 'unitex#jobexitcb'})
  if job_status(g:unitex#job) != 'run'
    call s:echoerr('(unitex#startjob): failed to open a unitex channel')
    return 1
  endif
  return 0
endfunc

func unitex#isjobrunning()
  return g:unitex#job isnot v:none && job_status(g:unitex#job) == 'run'
endfunc

func unitex#stopjob()
  " UnitexAssert unitex#isjobrunning()
  call job_stop(g:unitex#job)
  let g:unitex#job = v:none
endfunc

func unitex#on(bufnr)
  if index(g:unitex#buffers, a:bufnr) >= 0
    call unitex#off(a:bufnr)
  endif

  if !empty(getbufvar(a:bufnr, '&buftype'))
    echohl WarningMsg
    echomsg '(unitex#on):' s:refbuf(a:bufnr) 'is not a normal buffer'
    echohl NONE
  endif

  if !unitex#isjobrunning()
    if unitex#startjob()
      call s:echoerr("(unitex#on): couldn't open a unitex channel")
      return 1
    endif
  endif

  let l:lines = getbufline(a:bufnr, 1, '$')

  if unitex#filterlines(0, l:lines)
    call s:echoerr('(unitex#on): failed to filter ' . s:refbuf(a:bufnr) . ' with the unitex channel')
    if unitex#isjobrunning()
      call unitex#stopjob()
    endif
    return 1
  endif

  let l:prevmod = getbufvar(a:bufnr, '&modified')
  keepjumps call setbufline(a:bufnr, 1, l:lines)
  if !l:prevmod | call setbufvar(a:bufnr, '&modified', 0) | endif

  call setbufvar(a:bufnr, 'unitex_listener', listener_add('unitex#listener'))
  call add(g:unitex#buffers, a:bufnr)
  call setbufvar(a:bufnr, 'unitex_changes', [])

  call setbufvar(a:bufnr, 'unitex_keep_buftype', getbufvar(a:bufnr, '&buftype'))
  call setbufvar(a:bufnr, '&buftype', 'acwrite')
  exec 'aug unitex_b' . a:bufnr
    au!
    exec printf("au BufWriteCmd <buffer=%d> call unitex#write(%d, resolve(expand('<afile>')))", a:bufnr, a:bufnr)
    exec printf("au FileWriteCmd <buffer=%d> exec \"'[,']w%s %s\" resolve(expand('<afile>'))", a:bufnr, v:cmdbang? '!': '', v:cmdarg)
    exec printf("au FileAppendCmd <buffer=%d> exec \"'[,']w%s %s >>\" resolve(expand('<afile>'))", a:bufnr, v:cmdbang? '!': '', v:cmdarg)
    exec 'au SafeState <buffer=' . a:bufnr . '> call unitex#SafeState()'
  aug END
endfunc

func unitex#off(bufnr)
  if index(g:unitex#buffers, a:bufnr) >= 0
    let l:b = getbufvar(a:bufnr, '')

    exec 'au! unitex_b' . a:bufnr
    exec 'aug! unitex_b' . a:bufnr

    call setbufvar(a:bufnr, '&buftype', l:b.unitex_keep_buftype)
    unlet l:b.unitex_keep_buftype

    call listener_remove(l:b.unitex_listener)
    unlet l:b.unitex_listener
    unlet l:b.unitex_changes
    call remove(g:unitex#buffers, index(g:unitex#buffers, a:bufnr))

    if empty(g:unitex#buffers)
      call unitex#stopjob()
    endif
  endif

  let l:res = unitex#getrestoredbuf(a:bufnr)
  if l:res is v:none
    call s:echoerr('(unitex#off): failed to obtian restored content of ' . s:refbuf(a:bufnr))
    return 1
  endif
  call setbufline(a:bufnr, 1, l:res)

  return 0
endfunc

func unitex#peek()
  if !unitex#isjobrunning()
    call s:echoerr('(unitex#peek): unitex concealment is not turned on')
    return
  endif
  let l:lnum = line('.')
  let l:idx = col('.') - 1
  let l:line = getline(l:lnum)
  let l:mark = repeat("\t", count(l:line, "\t", 0, idx) + 1) . ' '
  let l:res = unitex#filterline(1, l:line[:idx-1] . l:mark . l:line[l:idx:])
  if l:res is v:none
    call s:echoerr('(unitex#peek): failed to filter current line')
    return 1
  endif
  let l:idx = strridx(l:res, l:mark)
  if l:idx < 0
    call s:echoerr('(unitex#peek): got corrupted result from the unitex channel')
    if unitex#isjobrunning()
      call unitex#stopjob()
    endif
    return 1
  endif
  keepjumps call setline(l:lnum, l:res[:l:idx-1] . l:res[l:idx+len(l:mark):])
  call cursor(l:lnum, l:idx + 1)
  return 0
endfunc

func unitex#jobexitcb(job, status)
  for l:bufnr in g:unitex#buffers
    call unitex#off(l:bufnr)
  endfor
  " UnitexAssert empty(g:unitex#buffers)
endfunc

func unitex#joberrcb(ch, msg)
  call s:echoerr('(from unitex on the background): ' . a:msg)
endfunc

func unitex#listener(bufnr, start, end, added, changes)
  if !unitex#isjobrunning()
    " Should be that the exit of job has just been detected in the call to
    " `isjobrunning`.
    return
  endif

  let l:ut = undotree()
  if l:ut.seq_cur != l:ut.seq_last
    return
  endif

  let l:b = getbufvar(a:bufnr, '')
  let l:lnums = l:b.unitex_changes
  for l:change in a:changes
    if l:change.added > 0
      for l:i in range(len(l:lnums))
        if l:lnums[l:i] >= l:change.lnum
          let l:lnums[l:i] += l:change.added
        endif
      endfor
      call extend(l:lnums, range(l:change.lnum, l:change.lnum + l:change.added - 1))
    elseif l:change.added < 0
      let l:i = 0
      while l:i < len(l:lnums)
        if l:lnums[l:i] + l:change.added >= l:change.lnum
          let l:lnums[l:i] += l:change.added
        elseif l:lnums[l:i] >= l:change.lnum
          unlet l:lnums[l:i]
          continue
        endif
        let l:i += 1
      endwhile
    else
      for l:n in range(l:change.lnum, l:change.end - 1)
        if index(l:lnums, l:n) < 0
          call add(l:lnums, l:n)
        endif
      endfor
    endif
  endfor
endfunc

func unitex#SafeState()
  if empty(b:unitex_changes)
    return
  endif

  let l:ut = undotree()
  if l:ut.seq_cur != l:ut.seq_last
    " Avoid messing up redo.
    return
  endif

  call listener_flush()
  let l:toset = []
  let l:pending = []

  for l:lnum in b:unitex_changes
    if l:lnum == line('.')
      call add(l:pending, l:lnum)
    else
      call listener_remove(b:unitex_listener)
      let l:line = getline(l:lnum)
      let l:res = unitex#filterline(0, l:line)
      if l:res isnot v:none
        if l:res != l:line
          call add(l:toset, [l:lnum, l:res])
        endif
      else
        call s:echoerr('(unitex#SafeState): failed to filter line ' . l:lnum)
        if unitex#isjobrunning()
          call unitex#stopjob()
        endif
      endif
      let b:unitex_listener = listener_add('unitex#listener')
    endif
  endfor

  if !empty(l:toset)
    undojoin
    for [l:lnum, l:newline] in l:toset
      keepjumps call setline(l:lnum, l:newline)
    endfor
  endif

  " UnitexAssert len(l:pending) <= 1
  let b:unitex_changes = l:pending
endfunc

func unitex#write(bufnr, fname)
  " UnitexAssert index(g:unitex#buffers, a:bufnr) >= 0
  let l:res = unitex#getrestoredbuf(a:bufnr)
  if l:res is v:none
    call s:echoerr('(unitex#write): failed to obtain restored content of ' . s:refbuf(a:bufnr) . ', writing failed')
    return
  endif
  if writefile(l:res, a:fname)
    call s:echoerr("(unitex#write): couldn't write to " . a:fname)
    return
  endif
  setlocal nomod
endfunc

func unitex#getrestoredbuf(bufnr)
  let l:ret = v:none
  if unitex#isjobrunning()
    let l:ret = getbufline(a:bufnr, 1, '$')
    if unitex#filterlines(1, l:ret)
      let l:ret = v:none
      call s:echoerr('(unitex#getrestoredbuf): failed to filter content of ' . s:refbuf(a:bufnr) . ' by the unitex channel')
    endif
  endif
  if l:ret is v:none
    " `silent` prevents the terminal from being set to cooked mode (:h system()).
    let l:cmd = 'unitex -r'
    silent let l:ret = systemlist(l:cmd, a:bufnr)
    if v:shell_error || len(l:ret) != line('$')
      if v:shell_error
        call s:echoerr(printf('(unitex#getrestoredbuf): failed to filter content of %s by running %s, shell returned %d', s:refbuf(a:bufnr), l:cmd, v:shell_error))
      else
        call s:echoerr('(unitex#getrestoredbuf): got corrupted result from running ' . l:cmd)
      endif
      let l:ret = v:none
    endif
  endif
  return l:ret
endfunc

func unitex#filterlines(reverse, lines)
  " UnitexAssert unitex#isjobrunning()
  for l:n in range(len(a:lines))
    let l:res = unitex#filterline(a:reverse, a:lines[l:n])
    if l:res isnot v:none
      let a:lines[l:n] = l:res
    else
      call s:echoerr('(unitex#filterlines): failed to filter lines')
      return 1
    endif
  endfor
  return 0
endfunc

func unitex#filterline(reverse, line)
  if empty(a:line)
    return a:line
  endif
  let l:res = ch_evalraw(g:unitex#job, printf("%s%s\n", a:reverse? '': '', a:line), {'timeout': 500})
  if empty(l:res)
    call s:echoerr('(unitex#filterline): failed to communicate with the unitex channel')
    if unitex#isjobrunning()
      call unitex#stopjob()
    endif
    return v:none
  else
    return l:res
  endif
endfunc

let &cpo = s:keep_cpo
unlet s:keep_cpo
