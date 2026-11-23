<p align="center">
  <img src="assets/pogo.jpg" alt="vim9pogo: a character with a monitor for a head, jumping on a pogo stick" width="280">
</p>

<h1 align="center">vim9pogo</h1>

<p align="center">A start page and dashboard for Vim, written in vim9script.</p>

Vim9pogo is a modern take on vim-startify. When Vim starts without a file it shows one page with the state of the whole setup: recent files from viminfo, the state of viminfo itself, errors from startup, the state of every plugin, and the run times of the plugin manager. Every file and every error has a key, so a session starts with one key press. It is written in pure vim9script and needs no other runtime.

```
    vim9pogo   dashboard for Vim
    Vim 9.2.0218  ·  Sunday 22 November 2026
    ~/dev/vim9-plum

    Recent files   6
    [1] ~/dev/vim9-plum/autoload/plum.vim                                    4h
    [2] ~/.vimplugins                                                        1d

    Plugins   9 loaded · 1 waiting · 0 missing
        manager  vim9-plum  a1b2c3d
      ● fakeft                    waits for filetype  ft=python
      ● vimhud                    loaded  6.0 ms

    Runtime
        plugin manager   activated 10 plugins in 38.2 ms
        slowest          fzf.vim 9.1 ms  ·  vimhud 6.0 ms
        last run         update in 4.1 s  12 done · 0 unchanged · 0 failed  2m ago

    Messages   1 errors · 0 warnings
    [3] E492  Not an editor command: foo  vimrc:10
```

## Requirements and installation

Vim 9.0 or later with `'encoding'` set to utf-8 is required, and Vim 9.2 is the target. The plugin has to be loaded at startup, so it cannot use the `ft` key of vim9-plum. With [vim9-plum](https://github.com/sevehub/vim9-plum), add it to `~/.vimplugins`:

```vim
vim9script

g:pogo_bookmarks = ['~/.vimplugins', '~/dev']

g:plum_plugins = [
  {url: 'sevehub/vim9pogo'},
]
```

## Usage

The page opens by itself when Vim is started without a file and without input from a pipe. `:Pogo` opens it in the current window, `:Pogo!` opens it in a new tab, and `:PogoRefresh` redraws it. A line is opened with `<CR>`, or with the key in brackets in front of it.

| Key | Action |
| --- | --- |
| `1` to `9`, `0`, `a` to `z` | Open the entry with that key (keys are listed in front of each entry) |
| `<CR>` | Open the entry under the cursor |
| `s`, `v`, `t` | Open the entry under the cursor in a split, a vertical split or a tab |
| `e` | Start an empty buffer |
| `i`, `u` | Run `:PlumInstall` or `:PlumUpdate` when vim9-plum is installed |
| `m` | Show the whole `:messages` text in a split |
| `r` | Refresh the page |
| `q` | Close the page, or quit when it is the only window |

## What the page shows

**Recent files** come from `v:oldfiles`, which Vim fills from viminfo. Files that no longer exist, git commit messages, swap files, temporary files and the help files of Vim itself are skipped. A second list shows the recent files below the current directory, and `g:pogo_bookmarks` adds a list of fixed entries.

**viminfo** shows the file that is in use, its size and age, and what it holds: recent files, commands, searches, global marks and registers. A warning appears when viminfo is disabled or the file does not exist yet.

**Messages** reads `:messages` and picks out errors and warnings, together with the file and line that Vim was processing. An entry with a known place opens that file at that line. Messages that start with a plugin tag (plum, inkpack, vimhud, pogo) are listed as warnings. The parser relies on the English message texts, so a translated Vim needs `:language messages C` to be fully understood.

**Plugins** shows every plugin as loaded, waiting for its filetype, optional or missing, with its pin and its load time. With vim9-plum the list comes from `plum#Stats()`. Without it, the plugins are found from the package directories.

**Runtime** shows what the plugin manager spent: the time vim9-plum needed to activate all plugins at startup, the slowest plugins, and the duration and result of the last install or update. It also counts the scripts that were sourced and the entries of `'runtimepath'`.

## Configuration

All settings are global variables. They fit in the list file of vim9-plum, above the plugin list.

| Variable | Default | Meaning |
| --- | --- | --- |
| `g:pogo_autostart` | `1` | Open the page when Vim starts without a file |
| `g:pogo_sections` | all, in order | Sections to show: `recent`, `here`, `bookmarks`, `plugins`, `runtime`, `viminfo`, `messages` |
| `g:pogo_width` | `76` | Width of the text column |
| `g:pogo_recent` | `8` | Number of recent files |
| `g:pogo_recent_here` | `5` | Number of recent files in the current directory |
| `g:pogo_skip` | git, temp and swap files | Regular expressions for paths that are left out |
| `g:pogo_bookmarks` | `[]` | Files and folders for the bookmark list |
| `g:pogo_plugins_max` | `12` | Rows in the plugin list; problems are shown first |
| `g:pogo_messages` | `6` | Number of errors and warnings shown |
| `g:pogo_message_tags` | plum, inkpack, vimhud, pogo | Message prefixes that count as plugin warnings |
| `g:pogo_logo` | `'auto'` | Mascot: `'auto'`, `'ascii'`, `'pixel'` or `0` |

## The mascot

The character with the monitor head on a pogo stick appears beside the page when the terminal is wide enough. `'ascii'` is the shaded ASCII art, colored cell by cell from the original image, and it needs about 130 columns. `'pixel'` is a compact version drawn with half-block characters, and it needs about 110 columns. With `'auto'` the larger one is chosen when it fits, then the smaller one, and then none. The sources are in `assets/` (`pogo.jpg` and `ascii-art.txt`) and the data that the plugin reads is in `autoload/pogo/`.

## Plugin manager data

The dashboard calls `plum#Stats()` of [vim9-plum](https://github.com/sevehub/vim9-plum), which returns the version of the manager, the time of the last activation in milliseconds, the last install or update run, and one entry for every listed plugin with its name, directory, pin, filetypes, whether it is installed and loaded, and its load time. 

## Status and limits

The ASCII mascot assumes a dark background. Load times are measured around `:packadd`, so they cover the plugin scripts of a plugin but not the lazy loading that happens later. The page is a buffer like any other, so a resize redraws it, but it is not live: `r` refreshes it.

## License

MIT, for the code. The artwork in `assets/` is the mascot of the project.
