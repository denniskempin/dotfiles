set nocompatible            " disable compatibility to old-time vi
set showmatch               " show matching
set ignorecase              " case insensitive
set hlsearch                " highlight search
set incsearch               " incremental search
set mouse=a                 " enable mouse click
set ttyfast                 " Speed up scrolling in Vim

call plug#begin()
    Plug 'kaicataldo/material.vim', { 'branch': 'main' }
call plug#end()

set termguicolors
let g:material_theme_style = 'darker'
colorscheme material
