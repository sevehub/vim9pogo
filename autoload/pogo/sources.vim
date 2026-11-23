vim9script

# Data sources of the dashboard. Everything here returns plain data and never
# touches the screen, so it can be tested without a user interface.

def Opt(name: string, fallback: any): any
  return get(g:, 'pogo_' .. name, fallback)
enddef

export def Norm(p: string): string
  return tr(p, '\', '/')
enddef

# A short age such as 5m, 3h, 2d, 4w or 7mo.
export def Age(ts: number): string
  if ts <= 0
    return ''
  endif
  const d = localtime() - ts
  if d < 60
    return 'now'
  elseif d < 3600
    return $'{d / 60}m'
  elseif d < 86400
    return $'{d / 3600}h'
  elseif d < 7 * 86400
    return $'{d / 86400}d'
  elseif d < 60 * 86400
    return $'{d / (7 * 86400)}w'
  endif
  return $'{d / (30 * 86400)}mo'
enddef

# Duration in milliseconds as 8 ms or 1.4 s.
export def Duration(ms: float): string
  if ms < 0
    return ''
  elseif ms < 100
    return printf('%.1f ms', ms)
  elseif ms < 1000
    return printf('%d ms', float2nr(ms))
  endif
  return printf('%.1f s', ms / 1000)
enddef

# ------------------------------------------------------------ recent files

# Files from v:oldfiles, which Vim fills from the viminfo file. The paths that
# match one of the skip patterns, or no longer exist, are left out. With under
# set, only files below that folder are returned.
export def Recent(limit: number, skip: list<string>, under: string = ''): list<dict<any>>
  var found: list<dict<any>> = []
  var seen: dict<bool> = {}
  for f in v:oldfiles
    const p = Norm(fnamemodify(expand(f), ':p'))
    if has_key(seen, p) || !filereadable(p)
      continue
    endif
    var skipped = false
    for pat in skip
      if p =~# pat
        skipped = true
        break
      endif
    endfor
    if skipped
      continue
    endif
    if under != '' && stridx(p, Norm(under) .. '/') != 0
      continue
    endif
    seen[p] = true
    found->add({path: p, time: getftime(p)})
    if len(found) >= limit
      break
    endif
  endfor
  return found
enddef

# ----------------------------------------------------------------- viminfo

export def Viminfo(): dict<any>
  var candidates: list<string> = []
  if &viminfofile != '' && &viminfofile !=# 'NONE'
    candidates->add(expand(&viminfofile))
  endif
  candidates += [expand('~/.viminfo'), expand('~/.vim/viminfo'), expand('~/_viminfo'), expand('~/vimfiles/viminfo')]
  var path = candidates[0]
  for c in candidates
    if filereadable(c)
      path = c
      break
    endif
  endfor
  var regs = 0
  for r in split('abcdefghijklmnopqrstuvwxyz0123456789"-', '\zs')
    if getreg(r) != ''
      regs += 1
    endif
  endfor
  var cmds = 0
  while cmds < &history && histget(':', -(cmds + 1)) != ''
    cmds += 1
  endwhile
  var searches = 0
  while searches < &history && histget('/', -(searches + 1)) != ''
    searches += 1
  endwhile
  return {
    enabled: &viminfo != '' && &viminfofile !=# 'NONE',
    option: &viminfo,
    path: Norm(path),
    exists: filereadable(path),
    size: getfsize(path),
    time: getftime(path),
    files: len(v:oldfiles),
    commands: cmds,
    searches: searches,
    marks: len(getmarklist()),
    registers: regs,
  }
enddef

# ---------------------------------------------------------------- messages

# Errors, warnings and tagged plugin messages found in :messages, oldest
# first. An item holds kind, code, text, ctx (what Vim was processing), lnum and
# jump, which is {file, lnum} when the place can be opened.
export def Messages(limit: number): list<dict<any>>
  var items: list<dict<any>> = []
  var ctx = ''
  var lnum = 0
  const tags: string = join(Opt('message_tags', ['plum', 'inkpack', 'vimhud', 'pogo']), '\|')
  for line in split(execute('messages'), "\n")
    var m = matchlist(line, '^Error detected while \(processing\|compiling\) \(.*\):$')
    if !empty(m)
      ctx = m[2]
      lnum = 0
      continue
    endif
    m = matchlist(line, '^line\s\+\(\d\+\):$')
    if !empty(m)
      lnum = str2nr(m[1])
      continue
    endif
    m = matchlist(line, '^\([EW]\d\+\): \(.*\)$')
    if !empty(m)
      items->add({kind: m[1][0] == 'E' ? 'error' : 'warning', code: m[1], text: m[2], ctx: ctx, lnum: lnum, jump: Jump(ctx, lnum)})
      continue
    endif
    m = matchlist(line, '^\(' .. tags .. '\): \(.*\)$')
    if !empty(m)
      items->add({kind: 'warning', code: m[1], text: m[2], ctx: '', lnum: 0, jump: {}})
      continue
    endif
    if line != ''
      ctx = ''
      lnum = 0
    endif
  endfor
  return len(items) > limit ? items[len(items) - limit :] : items
enddef

# A place that can be opened from the context of an error, or an empty dict.
def Jump(ctx: string, lnum: number): dict<any>
  if ctx == ''
    return {}
  endif
  var m = matchlist(ctx, '\(\f\+\)\[\(\d\+\)\]\.\.')
  if !empty(m) && filereadable(m[1])
    return {file: m[1], lnum: str2nr(m[2])}
  endif
  m = matchlist(ctx, '\(^\|script \)\(\f\+\)$')
  if !empty(m) && filereadable(m[2])
    return {file: m[2], lnum: lnum}
  endif
  return {}
enddef

# ----------------------------------------------------------------- plugins

# Statistics from the plugin manager when it offers them. This is vim9-plum,
# which exports Stats(); the call goes through its autoload name.
export def Plum(): dict<any>
  if globpath(&runtimepath, 'autoload/plum.vim', 1) == ''
    return {}
  endif
  try
    return call('plum#Stats', [])
  catch
    return {}
  endtry
enddef

# Plugins found as packages, for setups without a supported manager.
export def Packages(): list<dict<any>>
  var found: list<dict<any>> = []
  var rtp: list<string> = []
  for p in split(&runtimepath, ',')
    rtp->add(substitute(Norm(fnamemodify(p, ':p')), '/$', '', ''))
  endfor
  for kind in ['start', 'opt']
    for d in globpath(&packpath, $'pack/*/{kind}/*', 1, 1)
      if !isdirectory(d)
        continue
      endif
      const dir = substitute(Norm(fnamemodify(d, ':p')), '/$', '', '')
      const on = index(rtp, dir) >= 0
      found->add({name: fnamemodify(d, ':t'), dir: dir, installed: true, commit: '', ft: [], loaded: kind == 'start' || on, ms: -1.0, optional: kind == 'opt' && !on})
    endfor
  endfor
  return found
enddef

# ---------------------------------------------------------------- runtimes

export def Scripts(): number
  if exists('*getscriptinfo')
    return len(getscriptinfo())
  endif
  return len(split(execute('scriptnames'), "\n"))
enddef

export def RuntimePaths(): number
  return len(split(&runtimepath, ','))
enddef
