version 4.0 " avoid warning for wrong version
set nocompatible " Use Vim defaults like multi-undo (much better!)
set noedcompatible " turn off wierd :s///g behaviour (g always means g)
set background=dark " use light colors for a dark background (def: light)
set tabstop=3      " The width of a TAB is set to 3.
                    " Still it is a \t. It is just that
                    " Vim will interpret it to be having
                    " a width of 3.
set shiftwidth=3    " Indents will have a width of 3
set softtabstop=3   " Sets the number of columns for a TAB
set expandtab       " Expand TABs to spaces
" allow backspacing over everything in insert mode
set backspace=indent,eol,start
if has("vms")
  set nobackup          " do not keep a backup file, use versions instead
else
  set backup            " keep a backup file
endif
set history=50          " keep 50 lines of command line history
set ruler               " show the cursor position all the time
set showcmd             " display incomplete commands
set incsearch           " do incremental searching
set nomodeline
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif
syntax on " turn on syntax checking (after background is set)
" no-bold for color terminal comments
hi Comment cterm=NONE
" default non-text (formating) characters (default bold blue)
hi NonText term=bold cterm=bold ctermfg=0 " bold black --> IE: grey

