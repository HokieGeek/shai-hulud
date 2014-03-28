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
if !exists("g:shaihulud_split_window_size")
    let g:shaihulud_split_window_size = 10
endif

command! -nargs=* Build :call shaihulud#Build(<f-args>)
command! -bang -nargs=* Run :call shaihulud#LaunchCommandHere(<q-args>, <bang>0)

" vim: set foldmethod=marker formatoptions-=tc:
