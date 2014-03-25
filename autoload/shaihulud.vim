" Split the screen {{{
function! shaihulud#LaunchCommandInTmux(loc, cmd)
    " let l:cmd = "tmux split-window -d -l 10 \"".a:cmd." 2>&1 | tee ".tempname()."\""
    let l:cmd = "tmux split-window -d -l ".g:shaihulud_split_window_size." \"".a:cmd."\""
    " echomsg l:cmd
    call system(l:cmd)
endfunction

function! shaihulud#LaunchCommandInScreen(loc, cmd)
    let l:screen_cmd = "screen -dr ".expand("%STY")." -X"

    let l:cmd = l:screen_cmd." split"
    let l:cmd .= " && ".l:screen_cmd." focus"
    let l:cmd .= " && ".l:screen_cmd." resize ".g:shaihulud_split_window_size
    " let l:cmd .= " && ".l:screen_cmd." chdir ".expand("%:p:h")
    let l:cmd .= " && ".l:screen_cmd." screen"
    " let l:cmd .= " && ".l:screen_cmd." \"".a:cmd." 2>&1 | tee ".tempname()."\""
    let l:cmd .= " && ".l:screen_cmd." \"".a:cmd."\""
    call system(l:cmd)
endfunction

function! shaihulud#LaunchCommand(loc, cmd)
    if exists("$TMUX")
        call shaihulud#LaunchCommandInTmux(a:loc, a:cmd)
    elseif exists("$TERM") && expand("$TERM") == "screen"
        call shaihulud#LaunchCommandInScreen(a:loc, a:cmd)
    else
        echomsg "Did not find neither a tmux nor a screen session"
    endif
endfunction

function! shaihulud#LaunchCommandHere(cmd)
    call shaihulud#LaunchCommand(getcwd(), a:cmd)
endfunction
" }}}
function! shaihulud#BuildCommand(path, compiler, error_file) " {{{
    let l:output_file = tempname()
    let l:cmd_script = []
    if g:shaihulud_build_shell == "tcsh"
        call add(l:cmd_script, "#!/bin/tcsh -f")
    else
        " TODO
        " call add(l:cmd_script, "#!/bin/sh -f")
    endif
    if exists("b:shaihulud_build_env")
        for env in b:shaihulud_build_env
            call add(l:cmd_script, env)
        endfor
    endif
    call add(l:cmd_script, "cd ".a:path)
    if g:shaihulud_build_shell == "tcsh"
        if a:compiler == "ant"
            call add(l:cmd_script, a:compiler." |& tee ".l:output_file)
        else
            call add(l:cmd_script, "set num_processors=`grep -c \"processor\" /proc/cpuinfo`")
            call add(l:cmd_script, "set num_processors=`expr $num_processors + 1`")
            call add(l:cmd_script, a:compiler." -j${num_processors} |& tee ".l:output_file)
        endif
    else
        "TODO
    endif
    if len(l:cmd_script) > 0
        call add(l:cmd_script, "grep -i error: ".l:output_file." > ".a:error_file)
        let l:fname = tempname()
        call writefile(l:cmd_script, l:fname)
        silent execute "!chmod +x ".l:fname
        return "exec ".l:fname
    else
        echohl WarningMsg
        echomsg "Did not create a command script!"
        echohl None
        return "echo 'Did not create a command script!'"
    endif
endfunction
" }}}
function! shaihulud#GetBuildFramework(path) " {{{
    let l:path = a:path
    while (l:path != g:shaihulud_build_root_dir && len(l:path) > 0)
        if filereadable(l:path."/build.xml")
            return [l:path, "ant"]
        elseif filereadable(l:path."/makefile")
            return [l:path, "make"]
        elseif filereadable(l:path."/SConstruct")
            return [l:path, "scons"]
        else
            let l:path = fnamemodify(l:path, ":h")
        endif
    endwhile
    return []
endfunction
" }}}

function! shaihulud#Build(...)
    if a:0 > 0
        let l:build_info = shaihulud#GetBuildFramework(a:1) " TODO: a:000?
    else
        let l:build_info = shaihulud#GetBuildFramework(expand("%:p:h"))
    endif
    if len(l:build_info) > 0
        let b:build_error_file = tempname()
        let l:cmd = shaihulud#BuildCommand(l:build_info[0], l:build_info[1], b:build_error_file)
        call shaihulud#LaunchCommand(l:build_info[0], l:cmd)
        execute "cd ".l:build_info[0]
        command! -buffer BuildErrors :silent execute "cfile  ".b:build_error_file<bar>cwindow
        " FIXME: so.. how do I know that this is done so I can load the file?
    else
        echomsg "No clue what to build with"
    endif
endfunction

" vim: set foldmethod=marker formatoptions-=tc:
