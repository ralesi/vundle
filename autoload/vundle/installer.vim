func! vundle#installer#new(bang, ...) abort

  let bundles = (a:1 == '') ?
        \ g:bundles :
        \ map(copy(a:000), 'vundle#config#bundle(v:val, {})')

  let names = vundle#scripts#bundle_names(map(copy(bundles), 'v:val.name_spec'))
  call vundle#scripts#view('Installer',['" Installing bundles to '.expand(g:bundle_dir, 1)], names +  ['Helptags'])

  call s:process(a:bang, (a:bang ? 'add!' : 'add'))

  call vundle#config#require(bundles)
endf

func! vundle#installer#load(...) 
  " echom join(a:000,'')
  if type(a:000) == type ([]) && a:0 == 1
      let new_bundle = split(a:000[0],',')
  else
      let new_bundle = copy(a:000)
  endif


  let bundles = (a:0 == '') ?
        \ g:bundles :
        \ map(new_bundle, 'vundle#config#bundle(v:val, {})')

  " echo bundles
  " let names = map(copy(bundles), 'v:val.name_spec'))

  " check for parameter function
  for v in bundles
      :call vundle#installer#settings(v.name)
  endfor

  call vundle#config#require(bundles)

  " apply newly loaded ftbundles to currently open buffers
  " echom join(bundles,'')
  doautoall BufRead
endf

func! vundle#installer#settings(name)
  let name = substitute(a:name,'-\|\.','_','g')
  let name = tolower(name)

  " try
  "   call package#load()
  " catch
  " endtry

  if exists("*package#".name) && !exists("g:_".name."_loaded")
      " exec "echom 'package#".name."'"
      exec "call package#".name."()"
      exec "let g:_".name."_loaded=1"
  endif
  " endif
endfunc

func! s:process(bang, cmd)
  let msg = ''

  redraw
  sleep 1m

  let lines = (getline('.','$')[0:-2])

  for line in lines
    redraw

    exec ':norm '.a:cmd

    if 'error' == g:vundle_last_status
      let msg = 'With errors; press l to view log'
    endif

    " goto next one
    exec ':+1'

    setl nomodified
  endfor

  redraw
  echo 'Done! '.msg
endf

func! vundle#installer#run(func_name, name, ...) abort
  let n = a:name

  echo 'Processing '.n
  call s:sign('active')

  sleep 1m

  let status = call(a:func_name, a:1)

  call s:sign(status)

  redraw

  if 'updated' == status 
    echo n.' installed'
  elseif 'todate' == status
    echo n.' already installed'
  elseif 'deleted' == status
    echo n.' deleted'
  elseif 'error' == status
    echohl Error
    echo 'Error processing '.n
    echohl None
    sleep 1
  else
    throw 'whoops, unknown status:'.status
  endif

  let g:vundle_last_status = status

  return status
endf

func! s:sign(status) 
  if (!has('signs'))
    return
  endif

  exe ":sign place ".line('.')." line=".line('.')." name=Vu_". a:status ." buffer=" . bufnr("%")
endf

func! vundle#installer#install_and_require(bang, name) abort
 " echom 'required'
  let result = vundle#installer#install(a:bang, a:name)
  let b = vundle#config#bundle(a:name, {})
  call vundle#installer#helptags([b])
  call vundle#config#require([b])
  return result
endf

func! vundle#installer#install(bang, name) abort
  if !isdirectory(g:bundle_dir) | call mkdir(g:bundle_dir, 'p') | endif

  exec 'let current = filter(copy(g:bundles), "v:val.name_spec =~ '.a:name.'")'
  if !empty(current)
    let options = filter(copy(current[0]), 'v:key =~ "sync"') 
  else
    let options = {}
  endif
  let b = vundle#config#init_bundle(a:name, options)

  return s:sync(a:bang, b)
endf

func! vundle#installer#docs() abort
  call vundle#installer#helptags(g:bundles)
  return 'updated'
endf

func! vundle#installer#helptags(bundles) abort
  let bundle_dirs = map(copy(a:bundles),'v:val.rtpath')
  let help_dirs = filter(bundle_dirs, 's:has_doc(v:val)')

  call s:log('')
  call s:log('Helptags:')

  call map(copy(help_dirs), 's:helptags(v:val)')

  call s:log('Helptags: '.len(help_dirs).' bundles processed')

  return help_dirs
endf

func! vundle#installer#list(bang) abort
  let bundles = vundle#scripts#bundle_names(map(copy(g:bundles), 'v:val.name_spec'))
  call vundle#scripts#view('list', ['" My Bundles'], bundles)
  redraw
  " echo len(g:bundles).' bundles configured'
endf

func! vundle#installer#unloaded() abort
  let bundle_dirs = map(copy(g:bundles), 'v:val.path()') 
  let all_dirs = v:version >= 702 ? split(globpath(g:bundle_dir, '*', 1), "\n") : split(globpath(g:bundle_dir, '*'), "\n")
  let x_dirs = filter(all_dirs, '0 > index(bundle_dirs, v:val)')
  return map(copy(x_dirs), 'fnamemodify(v:val, ":t")')
endfunc

func! vundle#installer#clean(bang, name) abort

  let unloaded = vundle#installer#unloaded()

  if empty(unloaded)
    let headers = ['" All clean!']
    let names = []
  elseif a:name =~ join(unloaded,'\|')
    let headers = ['" Removing bundle:']
    let names = vundle#scripts#bundle_names([a:name])
  else
    let headers = ['" Removing bundles:']
    let names = vundle#scripts#bundle_names(unloaded)
  end

  call vundle#scripts#view('clean', headers, names)
  redraw

  if (a:bang || empty(names))
    call s:process(a:bang, 'D')
  else
    call inputsave()
    let response = input('Continue? [Y/n]: ')
    call inputrestore()
    if (response =~? 'y' || response == '')
      call s:process(a:bang, 'D')
    endif
  endif
endf


func! vundle#installer#delete(bang, dir_name) abort

  let cmd = (has('win32') || has('win64')) ?
  \           'rmdir /S /Q' :
  \           'rm -rf'

  let bundle = vundle#config#init_bundle(a:dir_name, {})
  let cmd .= ' '.shellescape(bundle.path())

  let out = s:system(cmd)

  call s:log('')
  call s:log('Bundle '.a:dir_name)
  call s:log('$ '.cmd)
  call s:log('> '.out)

  if 0 != v:shell_error
    return 'error'
  else
    return 'deleted'
  endif
endf

func! s:has_doc(rtp) abort
  return isdirectory(a:rtp.'/doc')
  \   && (!filereadable(a:rtp.'/doc/tags') || filewritable(a:rtp.'/doc/tags'))
  \   && v:version >= 702
  \     ? !(empty(glob(a:rtp.'/doc/*.txt', 1)) && empty(glob(a:rtp.'/doc/*.??x', 1)))
  \     : !(empty(glob(a:rtp.'/doc/*.txt')) && empty(glob(a:rtp.'/doc/*.??x')))
endf

func! s:helptags(rtp) abort
  let doc_path = a:rtp.'/doc/'
  call s:log(':helptags '.doc_path)
  try
    helptags `=doc_path`
  catch
    call s:log("> Error running :helptags ".doc_path)
  endtry
endf

func! s:sync(bang, bundle) abort

    " echom get(a:bundle,'sync')

  if get(a:bundle,'sync','yes') == 'no'
      return 'todate'
  endif

  let types = {'.git' : 'git', '.hg' : 'hg', '.bzr' : 'bzr', '.svn': 'svn' }
  " not sure if necessary, will detect DVCS type from directory
  if empty(a:bundle.type)
    for [k,t] in items(types)
      let repo_dir = expand(a:bundle.path().'/.'.k.'/')
      if isdirectory(repo_dir) | let type = t | break | endif
    endfor
  else
    let type = a:bundle.type
    let repo_dir = expand(a:bundle.path().'/.'.a:bundle.type.'/')
  endif

  let dir = shellescape(a:bundle.path())

  let vcs_update = {
        \'git': 'cd '.dir.' && git pull',
        \'hg':  'hg pull -u -R '.dir,
        \'bzr': 'bzr pull -d '.dir,
        \'svn': 'cd '.dir.' && svn update'}  

  let vcs_checkout = {
        \'git':  'git clone '.a:bundle.uri.' '.dir.'',
        \'hg':   'hg clone '.a:bundle.uri.' '.dir.'',
        \'bzr':  'bzr branch '.a:bundle.uri.' '.dir.'',
        \'svn':  ''}
  
  if type =~ '^\%(git\|hg\|bzr\|svn\)$'
    " if folder already exists, just pull
    if isdirectory(repo_dir)
      if !(a:bang) | return 'todate' | endif
      let cmd = vcs_update[type]
    else
      let cmd = vcs_checkout[type]
    endif
  else
    " how did we get here?
    return
  endif

  if s:iswindows()
    let cmd = substitute(cmd, '^cd ','cd /d ','')  " add /d switch to change drives
    " let cmd = '"'.cmd.'"'                          " enclose in quotes
  endif

  let out = s:system(cmd)

  let outlist = split(out,"\n",1)

  call s:log('')
  call s:log('Bundle '.a:bundle.name_spec)
  call s:log('$ '.cmd)

  for output in outlist
    if match(output,'^You') != -1
      let out = 0
    endif
    call s:log('> '.output)
  endfor

  if (0 != v:shell_error || [out] == [0])
    return 'error'
  end

  if out =~# 'up-to-date'
    return 'todate'
  end

  return 'updated'
endf

func! s:system(cmd) abort
    if exists("*xolox#shell#execute")
        let res = xolox#shell#execute(a:cmd,1)
        try
            return join(res,"\n")
        catch
            return res
        endtry
    else
        return system(a:cmd)
    endif
endf

func! s:log(str) abort
  let fmt = '%y%m%d %H:%M:%S'
  call add(g:vundle_log, '['.strftime(fmt).'] '.a:str)
  return a:str
endf

func! s:iswindows() abort
  return has("win16") || has("win32") || has("win64")
endf
