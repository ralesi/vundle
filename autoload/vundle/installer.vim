func! vundle#installer#new(bang, ...) abort
  let bundles = (a:1 == '') ?
        \ g:bundles :
        \ map(copy(a:000), 'vundle#config#bundle(v:val, {})')

  let names = vundle#scripts#bundle_names(map(copy(bundles), 'v:val.name_spec'))
  call vundle#scripts#view('Installer',['" Installing bundles to '.expand(g:bundle_dir, 1)], names +  ['Helptags'])

  call s:process(a:bang, (a:bang ? 'add!' : 'add'))

  call vundle#config#require(bundles)
endf

" adhoc load of bundle 
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

  " check for load rc configs
  for v in bundles
      call xolox#misc#msg#debug('Attempting to run name %s for bundle contents %s', v.name, v)
      call vundle#installer#rc(v.name)
  endfor

  call vundle#config#require(bundles)

  " apply newly loaded bundles to currently open buffers
  doautoall BufRead
endf

func! vundle#installer#rc(name) abort
  let name = substitute(a:name,'-\|\.','_','g')
  let name = tolower(name)

  " if exists("*rc#".name) && !exists("g:_".name."_loaded")
  if !exists("g:_".name."_loaded")
    try
      exec "call rc#".name."()"
    catch E117
      " plugin settings are not defined
    finally
      exec "let g:_".name."_loaded=1"
    endtry
  endif
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

    if 'updated' == g:vundle_last_status && empty(msg)
      let msg = 'Bundles updated; press u to view changelog'
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

  if 'new' == status
    echo n.' installed'
  elseif 'updated' == status
    echo n.' updated'
  elseif 'todate' == status
    echo n.' already installed'
  elseif 'deleted' == status
    echo n.' deleted'
  elseif 'helptags' == status
    echo n.' regenerated'
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
  let error_count = vundle#installer#helptags(g:bundles)
  if error_count > 0
      return 'error'
  endif
  return 'helptags'
endf

func! vundle#installer#helptags(bundles) abort
  let bundle_dirs = map(copy(a:bundles),'v:val.rtpath')
  let help_dirs = filter(bundle_dirs, 's:has_doc(v:val)')

  call s:log('')
  call s:log('Helptags:')

  let statuses = map(copy(help_dirs), 's:helptags(v:val)')
  let errors = filter(statuses, 'v:val == 0')

  call s:log('Helptags: '.len(help_dirs).' bundles processed')

  return len(errors)
endf

func! vundle#installer#list(bang) abort
  let bundles = vundle#scripts#bundle_names(map(copy(g:bundles), 'v:val.name_spec'))
  call vundle#scripts#view('list', ['" My Bundles'], bundles)
  redraw
  echo len(g:bundles).' bundles configured'
endf

func! vundle#installer#unloaded() abort
  let bundle_dirs = map(copy(g:bundles), 'v:val.path()') 
  let all_dirs = (v:version > 702 || (v:version == 702 && has("patch51")))
  \   ? split(globpath(g:bundle_dir, '*', 1), "\n")
  \   : split(globpath(g:bundle_dir, '*'), "\n")
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

  echo s:shell_error

  if 0 != s:shell_error
    return 'error'
  else
    return 'deleted'
  endif
endf

func! s:has_doc(rtp) abort
  return isdirectory(a:rtp.'/doc')
  \   && (!filereadable(a:rtp.'/doc/tags') || filewritable(a:rtp.'/doc/tags'))
  \   && (v:version > 702 || (v:version == 702 && has("patch51")))
  \     ? !(empty(glob(a:rtp.'/doc/*.txt', 1)) && empty(glob(a:rtp.'/doc/*.??x', 1)))
  \     : !(empty(glob(a:rtp.'/doc/*.txt')) && empty(glob(a:rtp.'/doc/*.??x')))
endf

func! s:helptags(rtp) abort
  let doc_path = a:rtp.'/doc/'
  call s:log(':helptags '.doc_path)
  try
    execute 'helptags ' . doc_path
  catch
    call s:log("> Error running :helptags ".doc_path)
    return 0
  endtry
  return 1
endf

func! s:sync(bang, bundle) abort

  let vcs_types = {'.git' : 'git', '.hg' : 'hg', '.bzr' : 'bzr', '.svn': 'svn' }


  " if type is not determined, detect DVCS type from directory
  if empty(a:bundle.type)
    for [k,t] in items(vcs_types)
      let repo_dir = expand(a:bundle.path().'/.'.k.'/',1)
      if isdirectory(repo_dir) | let type = t | break | endif
    endfor
  else
    let type = a:bundle.type
    let repo_dir = expand(a:bundle.path().'/.'.a:bundle.type.'/',1)
  endif

  let dir = shellescape(a:bundle.path())
  let uri = shellescape(a:bundle.uri)

  let vcs_update = {
        \'git': 'cd '.dir.' && git pull && git submodule update --init --recursive',
        \'hg':  'hg pull -u -R '.dir,
        \'bzr': 'bzr pull -d '.dir,
        \'svn': 'cd '.dir.' && svn update'}  

  let vcs_sha = {
        \'git': 'cd '.dir.' && git rev-parse HEAD',
        \'hg': '',
        \'bzr': '',
        \'svn': ''}  

  let vcs_checkout = {
        \'git':  'git clone --recursive '.uri.' '.dir.'',
        \'hg':   'hg clone '.uri.' '.dir.'',
        \'bzr':  'bzr branch '.uri.' '.dir.'',
        \'svn':  ''}

  if type =~ '^\%(git\|hg\|bzr\|svn\)$'
    " if folder already exists, just pull
    if isdirectory(repo_dir) || filereadable(expand(a:bundle.path().'/.git', 1))
      if !(a:bang) || get(a:bundle,'sync','yes') == 'no' | return 'todate' | endif

      let cmd = g:shellesc_cd(vcs_update[type])
      let initial_sha = s:system(vcs_sha[type])

    else
      let cmd = vcs_checkout[type]
      let initial_sha = ''
    endif
  else
    echo type . " repository is not supported"
    return
  endif

  let out = s:system(cmd)
  call s:log('')
  call s:log('Bundle '.a:bundle.name_spec)
  call s:log('$ '.cmd)
  call s:log('> '.out)

  if 0 != s:shell_error
    return 'error'
  end

  if empty(initial_sha)
    return 'new'
  endif

  let updated_sha = s:system(vcs_sha[type])

  if initial_sha == updated_sha
    return 'todate'
  end


  call add(g:updated_bundles, [initial_sha, updated_sha, a:bundle])
  return 'updated'
endf

func! g:shellesc(cmd) abort
  if (has('win32') || has('win64'))
    if &shellxquote != '('                           " workaround for patch #445
      return '"'.a:cmd.'"'                          " enclose in quotes so && joined cmds work
    endif
  endif
  return a:cmd
endf

func! g:shellesc_cd(cmd) abort
  if (has('win32') || has('win64'))
    let cmd = substitute(a:cmd, '^cd ','cd /d ','')  " add /d switch to change drives
    let cmd = g:shellesc(cmd)
    return cmd
  else
    return a:cmd
  endif
endf

func! s:system(cmd) abort
  if (has('win32') || has('win64'))
    if exists("*vimproc#cmd#system")
      let g:vundle_exec='vimproc'
    return vimproc#system(a:cmd)
  elseif exists("*xolox#misc#os#exec")
    let output=xolox#misc#os#exec({'command': a:cmd, 'async':0, 'check': 0})
    let out=(len(output.stderr)!=0) ? output.stderr : output.stdout
    let s:shell_error=(len(output.stderr)!=0) ? -1 : 0
    " return join(get(xolox#misc#os#exec({'command': a:cmd, 'check': 0}),'stdout',[]),'\r')
    return join(out,'\r')
    endif
  endif
  let g:vundle_exec='system'
    let out=system(a:cmd)
    let s:shell_error=v:shell_error
    return out
endf

func! s:log(str) abort
  let fmt = '%y%m%d %H:%M:%S'
  call add(g:vundle_log, '['.strftime(fmt).'] '.a:str)
  return a:str
endf
