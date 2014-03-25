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
command! -nargs=* Run :call shaihulud#LaunchCommandHere(<f-args>)

" vim: set foldmethod=marker formatoptions-=tc:
