vim9script

# vim9pogo: a start page and dashboard for Vim. Commands and autocommands only;
# the work is done in autoload/pogo.vim and autoload/pogo/*.vim.

if exists('g:loaded_pogo')
  finish
endif
g:loaded_pogo = 1

if &encoding != 'utf-8'
  echohl WarningMsg
  echomsg 'pogo: this plugin needs encoding=utf-8'
  echohl None
  finish
endif

import autoload 'pogo.vim'

command! -bang -bar Pogo pogo.Open(<bang>0)
command! -bar PogoRefresh pogo.Render()

augroup Pogo
  autocmd!
  autocmd StdinReadPre * g:pogo_stdin = true
  autocmd VimEnter * ++nested pogo.Start()
  autocmd VimResized * pogo.OnResize()
  autocmd ColorScheme * pogo.OnResize()
augroup END
