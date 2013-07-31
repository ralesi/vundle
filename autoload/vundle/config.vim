func! vundle#config#bundle(arg, ...)
  let bundle = vundle#config#init_bundle(a:arg, a:000)
  call s:rtp_rm_a()
  call add(g:bundles, bundle)
  call s:rtp_add_a()
  call vundle#installer#rc(bundle.name)
  return bundle
endf

func! vundle#config#init()
  if !exists('g:bundles') | let g:bundles = [] | endif
  call s:rtp_rm_a()
  let g:bundles = []
endf

func! vundle#config#require(bundles) abort
  for b in a:bundles
    call s:rtp_add(b.rtpath)
    call s:rtp_add(g:bundle_dir)
    " TODO: it has to be relative rtpath, not bundle.name
    exec 'runtime! '.b.name.'/plugin/*.vim'
    exec 'runtime! '.b.name.'/after/*.vim'
    call s:rtp_rm(g:bundle_dir)
  endfor
endf

func! vundle#config#init_bundle(name, opts)
  if a:name != substitute(a:name, '^\s*\(.\{-}\)\s*$', '\1', '')
    echo "Spurious leading and/or trailing whitespace found in bundle spec '" . a:name . "'"
  endif
  let opts = extend(s:parse_options(a:opts), s:parse_name(substitute(a:name,"['".'"]\+','','g')))
  let b = extend(opts, copy(s:bundle))
  let b.rtpath = s:rtpath(opts)
  let b.sync = has_key(opts, 'sync') ? opts.sync : 'yes'
  return b
endf

func! s:parse_options(opts)
  if type(a:opts) == type({})
    return a:opts
  elseif type(a:opts) == type([]) && len(a:opts) == 1
    return a:opts[0]
  else 
    return {} 
  endif
endf

func! s:parse_name(arg)
  let arg = a:arg
  let git_proto = exists('g:vundle_default_git_proto') ? g:vundle_default_git_proto : 'https'

  " default to git
  let type = 'git'

  " mercurial
  if arg[:3] ==# 'bit:'
      " bit:{N}/{repo}      {"type": "hg", "uri": "http://bitbucket.org/{Name}/{repo}}
      let uri = 'https://bitbucket.org/'.arg[len('bit:'):]
      let name = split(uri,'\/')[-1]
      let type = 'hg'
  elseif arg[:2]==#'hg:'
      " hg:{uri}          {"type": "hg", "uri": {uri}}
      let uri = arg[len('hg:'):]
      let name = split(uri,'\/')[-1]
      let type = 'hg'
      " bazaar
  elseif arg[:2]==#'lp:'
      let uri = arg
      let name = split (uri, ':')[-1]
      let type = 'bzr'
      " git
  elseif arg =~? '^\s*\(gh\|github\):\S\+'
  \  || arg =~? '^[a-z0-9][a-z0-9-]*/[^/]\+$'
      " github|gh:{N}/{Repo}  {"type": "git", "uri": "git://github.com/{N}/{Repo}"}
    let uri = git_proto.'://github.com/'.split(arg, ':')[-1]
    if uri !~? '\.git$'
      let uri .= '.git'
    endif
    let name = substitute(split(uri,'\/')[-1], '\.git\s*$','','i')
  elseif arg =~? '^\s*\(git@\|git://\)\S\+' 
  \   || arg =~? '\(file\|https\?\)://'
  \   || arg =~? '\.git\s*$'
      " git|https:{uri}          {"type": "git", "uri": {uri}}
    let uri = arg
    let name = split( substitute(uri,'/\?\.git\s*$','','i') ,'\/')[-1]
  else
    let name = arg
    let uri  = git_proto.'://github.com/vim-scripts/'.name.'.git'
  endif
  return {'name': name, 'uri': uri, 'name_spec': arg, 'type':type }
  endf

func! s:rtp_rm_a()
  let paths = map(copy(g:bundles), 'v:val.rtpath')
  let prepends = join(paths, ',')
  let appends = join(paths, '/after,').'/after'
  exec 'set rtp-='.fnameescape(prepends)
  exec 'set rtp-='.fnameescape(appends)
endf

func! s:rtp_add_a()
  let paths = map(copy(g:bundles), 'v:val.rtpath')
  let prepends = join(paths, ',')
  let appends = join(paths, '/after,').'/after'
  exec 'set rtp^='.fnameescape(prepends)
  exec 'set rtp+='.fnameescape(appends)
endf

func! s:rtp_rm(dir) abort
  exec 'set rtp-='.fnameescape(expand(a:dir, 1))
  exec 'set rtp-='.fnameescape(expand(a:dir.'/after', 1))
endf

func! s:rtp_add(dir) abort
  exec 'set rtp^='.fnameescape(expand(a:dir, 1))
  exec 'set rtp+='.fnameescape(expand(a:dir.'/after', 1))
endf

func! s:expand_path(path) abort
  return simplify(expand(a:path, 1))
endf

func! s:rtpath(opts)
  return has_key(a:opts, 'rtp') ? s:expand_path(a:opts.path().'/'.a:opts.rtp) : a:opts.path()
endf

let s:bundle = {}

func! s:bundle.path()
  return s:expand_path(g:bundle_dir.'/'.self.name)
endf

