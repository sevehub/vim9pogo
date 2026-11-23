vim9script

# vim9pogo: a start page and dashboard for Vim. It shows recent files from
# viminfo, the state of viminfo, errors from :messages, the state of the
# plugins and the run times of the plugin manager.

import autoload 'pogo/sources.vim'
import autoload 'pogo/mascot.vim'

const POOL = split('1234567890abcdfghlnwxyz', '\zs')
const TYPES = ['PogoTitle', 'PogoSection', 'PogoKey', 'PogoPath', 'PogoDim', 'PogoOk', 'PogoWarn', 'PogoErr', 'PogoText']
const SECTIONS = ['recent', 'here', 'bookmarks', 'plugins', 'runtime', 'viminfo', 'messages']

var buf = 0
var rows: list<dict<any>> = []
var keymap: dict<dict<any>> = {}
var line_item: dict<dict<any>> = {}
var next_key = 0
var width = 76

# ------------------------------------------------------------------ helpers

def Opt(name: string, fallback: any): any
  return get(g:, 'pogo_' .. name, fallback)
enddef

def Say(msg: string)
  echomsg 'pogo: ' .. msg
enddef

def DefineGroups()
  highlight default PogoTitle guifg=#d6a8f0 ctermfg=183 gui=bold cterm=bold
  highlight default PogoSection guifg=#7cb2ff ctermfg=111 gui=bold cterm=bold
  highlight default PogoKey guifg=#f5d76e ctermfg=221 gui=bold cterm=bold
  highlight default PogoPath guifg=#8f7ea6 ctermfg=103
  highlight default PogoDim guifg=#6b7280 ctermfg=243
  highlight default PogoOk guifg=#22c55e ctermfg=41
  highlight default PogoWarn guifg=#f59e0b ctermfg=214
  highlight default PogoErr guifg=#ef4444 ctermfg=203 gui=bold cterm=bold
  highlight default PogoText guifg=NONE
  for t in TYPES
    if empty(prop_type_get(t))
      prop_type_add(t, {highlight: t})
    endif
  endfor
enddef

def Shorten(s: string, max: number): string
  if strchars(s) <= max
    return s
  endif
  return '…' .. strcharpart(s, strchars(s) - max + 1)
enddef

# A row is built from [text, highlight] parts; item says what <CR> does.
def Row(parts: list<list<any>>, item: dict<any> = {})
  var text = ''
  var spans: list<list<any>> = []
  for part in parts
    if part[1] != '' && part[0] != ''
      spans->add([strlen(text), strlen(part[0]), part[1]])
    endif
    text ..= part[0]
  endfor
  rows->add({text: text, spans: spans, item: item})
enddef

def Blank()
  Row([])
enddef

def Heading(title: string, note: string = '', ntype: string = 'PogoDim')
  Blank()
  var parts: list<list<string>> = [['  ', ''], [title, 'PogoSection']]
  if note != ''
    parts->add(['   ' .. note, ntype])
  endif
  Row(parts)
enddef

# A row with a key hint. Keys come from a fixed pool, in order.
def Select(parts: list<list<any>>, item: dict<any>)
  var p: list<list<any>> = []
  var it = copy(item)
  if next_key < len(POOL)
    const key = POOL[next_key]
    next_key += 1
    it.key = key
    keymap[key] = it
    p = [['  [', 'PogoDim'], [key, 'PogoKey'], ['] ', 'PogoDim']]
  else
    p = [['      ', '']]
  endif
  p->extend(parts)
  Row(p, it)
enddef

# ----------------------------------------------------------------- sections

def Header()
  Blank()
  Row([['  vim9pogo', 'PogoTitle'], ['   dashboard for Vim', 'PogoDim']])
  const vl = v:versionlong
  Row([[$'  Vim {vl / 1000000}.{(vl / 10000) % 100}.{vl % 10000}', 'PogoText'], ['  ·  ' .. strftime('%A %d %B %Y'), 'PogoDim']])
  Row([['  ' .. fnamemodify(getcwd(), ':~'), 'PogoPath']])
enddef

def SkipPatterns(): list<string>
  const own = '^' .. escape(sources.Norm($VIMRUNTIME), '\.[]~*^$')
  return Opt('skip', ['COMMIT_EDITMSG$', '\.git/', '^/tmp/', '\.swp$']) + [own]
enddef

def FileRow(f: dict<any>)
  const tail = fnamemodify(f.path, ':t')
  var dir = fnamemodify(f.path, ':~:h')
  dir = dir == '.' ? '' : dir .. '/'
  const age = sources.Age(f.time)
  dir = Shorten(dir, max([8, width - 6 - strchars(tail) - strchars(age) - 1]))
  const gap = repeat(' ', max([1, width - 6 - strchars(dir) - strchars(tail) - strchars(age)]))
  Select([[dir, 'PogoPath'], [tail, 'PogoText'], [gap, ''], [age, 'PogoDim']], {kind: 'file', path: f.path})
enddef

def Recent()
  const files = sources.Recent(Opt('recent', 8), SkipPatterns())
  Heading('Recent files', string(len(files)))
  if empty(files)
    Row([['      nothing in viminfo yet', 'PogoDim']])
  endif
  for f in files
    FileRow(f)
  endfor
enddef

def Here()
  const files = sources.Recent(Opt('recent_here', 5), SkipPatterns(), getcwd())
  if empty(files)
    return
  endif
  Heading('Recent in ' .. fnamemodify(getcwd(), ':~'), string(len(files)))
  for f in files
    FileRow(f)
  endfor
enddef

def Bookmarks()
  const marks: list<string> = Opt('bookmarks', [])
  if empty(marks)
    return
  endif
  Heading('Bookmarks', string(len(marks)))
  for b in marks
    const path = sources.Norm(fnamemodify(expand(b), ':p'))
    Select([[Shorten(fnamemodify(path, ':~'), width - 8), 'PogoPath']], {kind: 'file', path: path})
  endfor
enddef

def PluginState(p: dict<any>): list<string>
  if !p.installed
    return ['missing', 'PogoErr', '0']
  elseif p.loaded
    return ['loaded', 'PogoOk', '3']
  elseif get(p, 'optional', false)
    return ['optional', 'PogoDim', '4']
  elseif !empty(p.ft)
    return ['waits for filetype', 'PogoWarn', '1']
  endif
  return ['not loaded', 'PogoWarn', '1']
enddef

def Plugins()
  const plum = sources.Plum()
  const plist: list<dict<any>> = empty(plum) ? sources.Packages() : plum.plugins
  if empty(plist) && empty(plum)
    return
  endif
  var states: list<dict<any>> = []
  var counts: dict<number> = {loaded: 0, waiting: 0, missing: 0}
  for p in plist
    const st = PluginState(p)
    states->add({p: p, label: st[0], type: st[1], rank: st[2]})
    if st[2] == '0'
      counts.missing += 1
    elseif st[2] == '1'
      counts.waiting += 1
    elseif st[2] == '3'
      counts.loaded += 1
    endif
  endfor
  sort(states, (a, b) => a.rank != b.rank ? (a.rank < b.rank ? -1 : 1) : (a.p.name < b.p.name ? -1 : a.p.name > b.p.name ? 1 : 0))
  const worst = counts.missing > 0 ? 'PogoErr' : counts.waiting > 0 ? 'PogoWarn' : 'PogoOk'
  Heading('Plugins', $'{counts.loaded} loaded · {counts.waiting} waiting · {counts.missing} missing', worst)
  if !empty(plum)
    Row([['      manager  ', 'PogoDim'], ['vim9-plum', 'PogoText'], [empty(plum.version) ? '' : '  ' .. plum.version, 'PogoPath']])
  else
    Row([['      no plugin manager data; listing packages', 'PogoDim']])
  endif
  const most: number = Opt('plugins_max', 12)
  var shown = 0
  for s in states
    if shown >= most
      break
    endif
    var detail: list<string> = []
    if s.p.commit != ''
      detail->add('pin ' .. strpart(s.p.commit, 0, 7))
    endif
    if !empty(s.p.ft)
      detail->add('ft=' .. join(s.p.ft, ','))
    endif
    if s.p.ms >= 0
      detail->add(sources.Duration(s.p.ms))
    endif
    const name = Shorten(s.p.name, 24)
    Row([['    ● ', s.type], [name, 'PogoText'], [repeat(' ', max([1, 26 - strchars(name)])), ''], [s.label, s.type == 'PogoOk' ? 'PogoDim' : s.type], ['  ' .. join(detail, '  '), 'PogoDim']])
    shown += 1
  endfor
  if len(states) > shown
    Row([[$'      … and {len(states) - shown} more', 'PogoDim']])
  endif
enddef

def Runtime()
  const plum = sources.Plum()
  Heading('Runtime')
  if !empty(plum)
    Row([['      plugin manager   ', 'PogoDim'], [$'activated {len(plum.plugins)} plugins in ', 'PogoText'], [sources.Duration(plum.activate_ms), 'PogoKey']])
    var timed: list<dict<any>> = []
    for p in plum.plugins
      if p.ms >= 0
        timed->add(p)
      endif
    endfor
    sort(timed, (a, b) => a.ms > b.ms ? -1 : a.ms < b.ms ? 1 : 0)
    if !empty(timed)
      const top = mapnew(timed[0 : 2], (_, p) => $'{p.name} {sources.Duration(p.ms)}')
      Row([['      slowest          ', 'PogoDim'], [join(top, '  ·  '), 'PogoText']])
    endif
    const lr = plum.last_run
    if empty(lr)
      Row([['      last run         ', 'PogoDim'], ['none in this session', 'PogoDim']])
    else
      const when = sources.Age(lr.when)
      Row([['      last run         ', 'PogoDim'], [$'{lr.action} in {sources.Duration(lr.ms)}', 'PogoText'], [$'  {lr.ok} done · {lr.skipped} unchanged · ', 'PogoDim'], [$'{lr.failed} failed', lr.failed > 0 ? 'PogoErr' : 'PogoDim'], [$'  {when == "now" ? "just now" : when .. " ago"}', 'PogoDim']])
    endif
  else
    Row([['      no plugin manager statistics (vim9-plum provides them)', 'PogoDim']])
  endif
  Row([['      vim              ', 'PogoDim'], [$'{sources.Scripts()} scripts sourced  ·  {sources.RuntimePaths()} runtimepath entries', 'PogoText']])
enddef

def Viminfo()
  const vi = sources.Viminfo()
  Heading('viminfo', vi.enabled ? '' : 'disabled', 'PogoWarn')
  Row([['      ', ''], [Shorten(fnamemodify(vi.path, ':~'), width - 8), 'PogoPath']])
  if !vi.exists
    Row([['      not written yet', 'PogoWarn']])
  else
    const age = sources.Age(vi.time)
    Row([[printf('      %.1f KB  ·  written %s ago', vi.size / 1024.0, age == 'now' ? '0m' : age), 'PogoDim']])
  endif
  Row([[$'      {vi.files} files  ·  {vi.commands} commands  ·  {vi.searches} searches  ·  {vi.marks} marks  ·  {vi.registers} registers', 'PogoText']])
enddef

def Messages()
  const items = sources.Messages(Opt('messages', 6))
  var nerr = 0
  var nwarn = 0
  for it in items
    if it.kind == 'error'
      nerr += 1
    else
      nwarn += 1
    endif
  endfor
  if empty(items)
    Heading('Messages', 'no errors', 'PogoOk')
    return
  endif
  Heading('Messages', $'{nerr} errors · {nwarn} warnings', nerr > 0 ? 'PogoErr' : 'PogoWarn')
  for it in items
    const type = it.kind == 'error' ? 'PogoErr' : 'PogoWarn'
    const place = empty(it.jump) ? '' : $'{fnamemodify(it.jump.file, ":t")}:{it.jump.lnum}'
    const text = Shorten(it.text, max([10, width - 16 - strchars(it.code) - strchars(place)]))
    const parts = [[it.code, type], ['  ', ''], [text, 'PogoText'], [place == '' ? '' : '  ' .. place, 'PogoDim']]
    if empty(it.jump)
      var full: list<list<any>> = [['      ', '']]
      full->extend(parts)
      Row(full)
    else
      Select(parts, {kind: 'jump', file: it.jump.file, lnum: it.jump.lnum})
    endif
  endfor
enddef

def Footer()
  Blank()
  var parts: list<list<string>> = [['  ', '']]
  for [key, label] in [['e', 'new file'], ['i', 'install'], ['u', 'update'], ['m', 'messages'], ['r', 'refresh'], ['q', 'quit']]
    parts->add(['[', 'PogoDim'])
    parts->add([key, 'PogoKey'])
    parts->add([$'] {label}   ', 'PogoDim'])
  endfor
  Row(parts)
enddef

def Build()
  rows = []
  keymap = {}
  next_key = 0
  Header()
  for s in Opt('sections', SECTIONS)
    if s == 'recent'
      Recent()
    elseif s == 'here'
      Here()
    elseif s == 'bookmarks'
      Bookmarks()
    elseif s == 'plugins'
      Plugins()
    elseif s == 'runtime'
      Runtime()
    elseif s == 'viminfo'
      Viminfo()
    elseif s == 'messages'
      Messages()
    endif
  endfor
  Footer()
enddef

# ---------------------------------------------------------------- rendering

export def Render()
  if buf == 0 || !bufexists(buf)
    return
  endif
  DefineGroups()
  const win = bufwinid(buf)
  const total = win > 0 ? winwidth(win) : &columns
  width = Opt('width', 76)
  Build()
  const setting = Opt('logo', 'auto')
  const want: string = type(setting) == v:t_string ? setting : (setting == 0 ? 'none' : 'auto')
  var kind = 'none'
  if want == 'ascii' || want == 'pixel'
    kind = want
  elseif want == 'auto'
    for k in ['ascii', 'pixel']
      if kind == 'none' && mascot.Width(k) > 0 && total >= width + 4 + mascot.Width(k) + 2
        kind = k
      endif
    endfor
  endif
  const logo: list<dict<any>> = kind == 'none' ? [] : mascot.Rows(kind)
  const lw = kind == 'none' ? 0 : mascot.Width(kind)
  const block = empty(logo) ? width : width + 4 + lw
  const pad = repeat(' ', max([0, (total - block) / 2]))
  const off = strlen(pad)
  var lines: list<string> = []
  var spans_all: list<list<list<any>>> = []
  line_item = {}
  for i in range(max([len(rows), len(logo)]))
    var text = i < len(rows) ? rows[i].text : ''
    var spans: list<list<any>> = i < len(rows) ? copy(rows[i].spans) : []
    if i < len(rows) && !empty(rows[i].item)
      line_item[string(i + 1)] = rows[i].item
    endif
    if !empty(logo)
      text ..= repeat(' ', max([1, width - strdisplaywidth(text)])) .. '    '
      if i < len(logo)
        const base = strlen(text)
        for sp in logo[i].spans
          spans->add([base + sp[0], sp[1], sp[2]])
        endfor
        text ..= logo[i].text
      endif
    endif
    lines->add(pad .. text)
    spans_all->add(spans)
  endfor
  setbufvar(buf, '&modifiable', 1)
  prop_clear(1, getbufinfo(buf)[0].linecount, {bufnr: buf})
  deletebufline(buf, 1, '$')
  setbufline(buf, 1, lines)
  for i in range(len(lines))
    for sp in spans_all[i]
      prop_add(i + 1, off + sp[0] + 1, {bufnr: buf, length: sp[1], type: sp[2]})
    endfor
  endfor
  setbufvar(buf, '&modifiable', 0)
  setbufvar(buf, '&modified', 0)
enddef

# Lines of the dashboard buffer, for tests and for copying.
export def Lines(): list<string>
  return buf != 0 && bufexists(buf) ? getbufline(buf, 1, '$') : []
enddef

# --------------------------------------------------------------- actions

def Go(item: dict<any>, how: string)
  const kind = get(item, 'kind', '')
  if kind == 'file'
    execute how fnameescape(item.path)
  elseif kind == 'jump'
    execute how fnameescape(item.file)
    cursor(item.lnum, 1)
  endif
enddef

def Press(key: string)
  if has_key(keymap, key)
    Go(keymap[key], 'edit')
  endif
enddef

def OpenAtCursor(how: string)
  const item = get(line_item, string(line('.')), {})
  if !empty(item)
    Go(item, how)
  endif
enddef

def NewFile()
  enew
enddef

def Quit()
  if winnr('$') == 1 && tabpagenr('$') == 1
    quit
  else
    close
  endif
enddef

def Run(cmd: string)
  if exists(':' .. cmd) == 2
    execute cmd
  else
    Say($'{cmd} is not available; vim9-plum provides it')
  endif
enddef

def ShowMessages()
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setline(1, split(execute('messages'), "\n"))
  normal! G
enddef

def Refresh()
  const lnum = line('.')
  Render()
  cursor(min([lnum, line('$')]), 1)
enddef

def SetupBuffer()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nonumber norelativenumber nowrap nospell nolist cursorline signcolumn=no foldcolumn=0 colorcolumn=
  setlocal filetype=pogo
  for k in POOL
    execute $'nnoremap <buffer> <nowait> <silent> {k} <ScriptCmd>Press("{k}")<CR>'
  endfor
  nnoremap <buffer> <nowait> <silent> <CR> <ScriptCmd>OpenAtCursor('edit')<CR>
  nnoremap <buffer> <nowait> <silent> s <ScriptCmd>OpenAtCursor('split')<CR>
  nnoremap <buffer> <nowait> <silent> v <ScriptCmd>OpenAtCursor('vsplit')<CR>
  nnoremap <buffer> <nowait> <silent> t <ScriptCmd>OpenAtCursor('tabedit')<CR>
  nnoremap <buffer> <nowait> <silent> e <ScriptCmd>NewFile()<CR>
  nnoremap <buffer> <nowait> <silent> q <ScriptCmd>Quit()<CR>
  nnoremap <buffer> <nowait> <silent> r <ScriptCmd>Refresh()<CR>
  nnoremap <buffer> <nowait> <silent> m <ScriptCmd>ShowMessages()<CR>
  nnoremap <buffer> <nowait> <silent> i <ScriptCmd>Run('PlumInstall')<CR>
  nnoremap <buffer> <nowait> <silent> u <ScriptCmd>Run('PlumUpdate')<CR>
enddef

# ------------------------------------------------------------- entry points

export def Open(newtab: bool)
  if newtab
    tabnew
  else
    try
      enew
    catch
      Say('the current buffer has changes; save it or use :Pogo!')
      return
    endtry
  endif
  buf = bufnr()
  const old = bufnr('^Pogo$')
  if old > 0 && old != buf
    execute 'silent! bwipeout!' old
  endif
  silent! keepalt file Pogo
  SetupBuffer()
  Render()
  var first = 0
  for k in keys(line_item)
    if first == 0 || str2nr(k) < first
      first = str2nr(k)
    endif
  endfor
  if first > 0
    cursor(first, 1)
  endif
enddef

# Called at VimEnter: show the page when Vim was started without a file.
export def Start()
  if Opt('autostart', 1) == 0 || get(g:, 'pogo_stdin', false) || argc() != 0
    return
  endif
  if bufname() != '' || &modified || line('$') > 1 || getline(1) != '' || &diff
    return
  endif
  Open(false)
enddef

export def OnResize()
  if buf != 0 && bufexists(buf) && bufwinid(buf) > 0
    Render()
  endif
enddef
