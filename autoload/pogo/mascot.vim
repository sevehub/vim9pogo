vim9script

# The pogo mascot in two forms. ascii.txt is the shaded ASCII art with a color
# for every cell; mascot.txt is a compact pixel version. The pixel form is
# described below.
#
# The pogo mascot as pixel art. mascot.txt holds a palette line and rows of
# letters (a space is transparent). Two pixel rows share one text row: the
# upper half block takes the color of the upper pixel as foreground and the
# color of the lower pixel as background. Colors come from highlight groups
# named PogoPx<top><bottom> and are shown through text properties.

const DIR = expand('<script>:p:h')

var palette: list<string> = []
var pixels: list<string> = []
var defined: dict<bool> = {}
var apalette: list<string> = []
var aglyphs: list<string> = []
var acolors: list<string> = []

def Load()
  if !empty(palette)
    return
  endif
  const file = DIR .. '/mascot.txt'
  if !filereadable(file)
    return
  endif
  const lines = readfile(file)
  palette = split(substitute(lines[0], '^palette ', '', ''), ',')
  pixels = lines[1 :]
  if len(pixels) % 2 == 1
    pixels->add('')
  endif
enddef

# Nearest color of the xterm 256-color cube.
def Cterm(hex: string): number
  const r = str2nr(strpart(hex, 0, 2), 16)
  const g = str2nr(strpart(hex, 2, 2), 16)
  const b = str2nr(strpart(hex, 4, 2), 16)
  return 16 + 36 * ((r * 5 + 127) / 255) + 6 * ((g * 5 + 127) / 255) + ((b * 5 + 127) / 255)
enddef

def Letter(row: string, x: number): string
  const c = strpart(row, x, 1)
  return c == '' || c == ' ' ? '' : c
enddef

def Define(fg: string, bg: string): string
  const name = $'PogoPx{fg}{bg == "" ? "_" : bg}'
  if has_key(defined, name)
    return name
  endif
  defined[name] = true
  const fhex = palette[char2nr(fg) - 65]
  var cmd = $'highlight {name} guifg=#{fhex} ctermfg={Cterm(fhex)}'
  if bg == ''
    cmd ..= ' guibg=NONE ctermbg=NONE'
  else
    const bhex = palette[char2nr(bg) - 65]
    cmd ..= $' guibg=#{bhex} ctermbg={Cterm(bhex)}'
  endif
  execute cmd
  if empty(prop_type_get(name))
    prop_type_add(name, {highlight: name})
  endif
  return name
enddef

# ascii.txt: a palette line, the glyph rows, a line with three dashes, and the
# color rows, one palette letter per glyph (a space means no glyph).
def LoadAscii()
  if !empty(aglyphs)
    return
  endif
  const file = DIR .. '/ascii.txt'
  if !filereadable(file)
    return
  endif
  const lines = readfile(file)
  apalette = split(substitute(lines[0], '^palette ', '', ''), ',')
  const cut = index(lines, '---')
  aglyphs = lines[1 : cut - 1]
  acolors = lines[cut + 1 :]
enddef

def DefineAscii(letter: string): string
  const name = 'PogoAsc' .. letter
  if has_key(defined, name)
    return name
  endif
  defined[name] = true
  const hex = apalette[char2nr(letter) - 65]
  execute $'highlight {name} guifg=#{hex} guibg=NONE ctermfg={Cterm(hex)} ctermbg=NONE'
  if empty(prop_type_get(name))
    prop_type_add(name, {highlight: name})
  endif
  return name
enddef

# Width in columns of a mascot form ('ascii' or 'pixel'), 0 when unavailable.
export def Width(kind: string = 'pixel'): number
  if kind == 'ascii'
    LoadAscii()
    return empty(aglyphs) ? 0 : strlen(aglyphs[0])
  endif
  if &encoding != 'utf-8'
    return 0
  endif
  Load()
  return empty(pixels) ? 0 : strlen(pixels[0])
enddef

export def Height(kind: string = 'pixel'): number
  if kind == 'ascii'
    LoadAscii()
    return len(aglyphs)
  endif
  Load()
  return len(pixels) / 2
enddef

def AsciiRows(): list<dict<any>>
  var out: list<dict<any>> = []
  defined = {}
  for y in range(len(aglyphs))
    const glyphs = aglyphs[y]
    const colors = y < len(acolors) ? acolors[y] : ''
    var spans: list<list<any>> = []
    for x in range(strlen(glyphs))
      const c = strpart(colors, x, 1)
      if c == '' || c == ' ' || strpart(glyphs, x, 1) == ' '
        continue
      endif
      const group = DefineAscii(c)
      const last = len(spans) - 1
      if last >= 0 && spans[last][2] == group && spans[last][0] + spans[last][1] == x
        spans[last][1] += 1
      else
        spans->add([x, 1, group])
      endif
    endfor
    out->add({text: glyphs, spans: spans})
  endfor
  return out
enddef

# Rows of {text, spans}; spans are [byte column, byte length, group].
export def Rows(kind: string = 'pixel'): list<dict<any>>
  if Width(kind) == 0
    return []
  endif
  if kind == 'ascii'
    return AsciiRows()
  endif
  defined = {}
  var out: list<dict<any>> = []
  const w = strlen(pixels[0])
  for y in range(0, len(pixels) - 2, 2)
    var text = ''
    var spans: list<list<any>> = []
    for x in range(w)
      const top = Letter(pixels[y], x)
      const bot = Letter(pixels[y + 1], x)
      var glyph = ' '
      var group = ''
      if top == '' && bot == ''
        glyph = ' '
      elseif top != '' && bot == ''
        glyph = '▀'
        group = Define(top, '')
      elseif top == '' && bot != ''
        glyph = '▄'
        group = Define(bot, '')
      elseif top == bot
        glyph = '█'
        group = Define(top, '')
      else
        glyph = '▀'
        group = Define(top, bot)
      endif
      if group != ''
        const last = len(spans) - 1
        if last >= 0 && spans[last][2] == group && spans[last][0] + spans[last][1] == strlen(text)
          spans[last][1] += strlen(glyph)
        else
          spans->add([strlen(text), strlen(glyph), group])
        endif
      endif
      text ..= glyph
    endfor
    out->add({text: text, spans: spans})
  endfor
  return out
enddef
