if exists("g:autoloaded_shaihulud") || v:version < 700
    finish
endif
let g:autoloaded_shaihulud = 1

" Execute command {{{
function! shaihulud#LaunchCommandInTmux(loc, cmd)
    " let l:cmd = "tmux new-window -n ".a:title." -d \"cd ".a:loc.";".a:cmd."\""

    let l:cmd = "tmux split-window -d -l ".g:shaihulud_split_window_size." \"cd ".a:loc.";".a:cmd."\""
    call system(l:cmd)
endfunction

function! shaihulud#LaunchCommandInScreen(loc, cmd)
    let l:screen_cmd = "screen -dr ".expand("%STY")." -X"

    " let l:cmd = l:screen_cmd." screen -t ".a:title." \"cd ".a:loc.";".a:cmd."\""

    let l:cmd = l:screen_cmd." split"
    let l:cmd .= " && ".l:screen_cmd." focus"
    let l:cmd .= " && ".l:screen_cmd." resize ".g:shaihulud_split_window_size
    " let l:cmd .= " && ".l:screen_cmd." chdir ".expand("%:p:h")
    let l:cmd .= " && ".l:screen_cmd." screen"
    let l:cmd .= " && ".l:screen_cmd." \"cd ".a:loc.";".a:cmd."\""
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
function! shaihulud#BuildCommand(path, compiler) " {{{
    let l:output_file = tempname()
    let l:cmd_script = []

    "" Add the preprocessor line
    if match(g:shaihulud_build_shell, "csh") > -1
        call add(l:cmd_script, "#!/bin/tcsh -f")
    else
        call add(l:cmd_script, "#!/bin/sh -f")
    endif

    "" Add any user environment commands
    if exists("b:shaihulud_build_env")
        for env in b:shaihulud_build_env
            call add(l:cmd_script, env)
        endfor
    endif

    "" Cd to that location
    call add(l:cmd_script, "cd ".a:path)

    "" Build the execution line for the compiler
    let l:compiler_line = a:compiler
    if a:compiler != "ant"
        " TODO: I don't think /proc/cpuinfo is portable
        if match(g:shaihulud_build_shell, "csh") > -1
            call add(l:cmd_script, "set num_processors=`grep -c \"processor\" /proc/cpuinfo`")
            call add(l:cmd_script, "set num_processors=`expr $num_processors + 1`")
        else
            call add(l:cmd_script, "num_processors=`expr $(grep -c \"processor\" /proc/cpuinfo) + 1`")
        endif

        let l:compiler_line .= " -j${num_processors} "
    endif
    if match(g:shaihulud_build_shell, "csh") > -1
        let l:pipe = "|&"
    else
        let l:pipe = "2>&1 |"
    endif
    let l:compiler_line .= " ".l:pipe." tee ".l:output_file
    call add(l:cmd_script, l:compiler_line)

    "" If a script was generated, add the line to retrieve the errors and write the file
    if len(l:cmd_script) > 0
        call add(l:cmd_script, "grep -i ': error: ' ".l:output_file." > ".b:shaihulud_build_error_file)
        call add(l:cmd_script, "grep -i ': warning: ' ".l:output_file." > ".b:shaihulud_build_warning_file)
        call add(l:cmd_script, "touch ".b:shaihulud_build_completed)
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
        elseif filereadable(l:path."/makefile") || filereadable(l:path."/Makefile")
            return [l:path, "make"]
        elseif filereadable(l:path."/rakefile")
            return [l:path, "rake"]
        elseif filereadable(l:path."/SConstruct")
            return [l:path, "scons"]
        else
            let l:path = fnamemodify(l:path, ":h")
        endif
    endwhile
    return []
endfunction
" }}}
function! shaihulud#CheckBuildCompleted(path) " {{{
    if exists("b:shaihulud_build_completed") && filereadable(expand(b:shaihulud_build_completed))
        execute "cd ".a:path
        command! -buffer BuildErrors :silent execute 'cfile  '.b:shaihulud_build_error_file<bar>cwindow
        command! -buffer BuildWarnings :silent execute 'cfile  '.b:shaihulud_build_warnings_file<bar>cwindow
        execute "BuildErrors"

        unlet! b:shaihulud_build_completed
        autocmd! VimResized <buffer>
    endif
endfunction
" }}}
function! shaihulud#Build(...)
    if a:0 > 0
        let l:build_info = shaihulud#GetBuildFramework(join(a:000, ' '))
    else
        let l:build_info = shaihulud#GetBuildFramework(expand("%:p:h"))
    endif
    if len(l:build_info) > 0
        let b:shaihulud_build_error_file = tempname()
        let b:shaihulud_build_warning_file = tempname()
        let b:shaihulud_build_completed = tempname()
        let l:cmd = shaihulud#BuildCommand(l:build_info[0], l:build_info[1])
        call shaihulud#LaunchCommand(l:build_info[0], l:cmd)
        execute "autocmd VimResized <buffer> call shaihulud#CheckBuildCompleted('".l:build_info[0]."')"
    else
        echomsg "No clue what to build with"
    endif
endfunction

" vim: set foldmethod=marker formatoptions-=tc:
