if exists("g:loaded_shaihulud") || v:version < 700
    finish
endif
let g:loaded_shaihulud = 1

if !exists("g:shaihulud_build_root_dir")
    let g:shaihulud_build_root_dir = "/"
endif
if !exists("g:shaihulud_build_shell")
    let g:shaihulud_build_shell = "sh"
endif

let g:shaihulud_build_completion_listeners = []
let g:shaihulud_errorformat_ant=escape('%A\ %#[javac]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#', ' \')

command! -nargs=* Build :call shaihulud#Build(<f-args>)

" vim: set foldmethod=marker formatoptions-=tc:
