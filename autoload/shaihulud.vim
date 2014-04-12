if exists("g:autoloaded_shaihulud") || v:version < 700
    finish
endif
let g:autoloaded_shaihulud = 1

function! shaihulud#BuildCommand(path, compiler, compiler_args) " {{{
    let l:output_file = tempname()
    let l:cmd_script = []

    "" Add the preprocessor line
    call add(l:cmd_script, "#!/bin/".g:shaihulud_build_shell." -f")

    "" Add any user environment commands
    if exists("b:shaihulud_build_env")
        let l:cmd_script += b:shaihulud_build_env
    endif

    "" Cd to that location
    call add(l:cmd_script, "cd ".a:path)

    "" Build the execution line for the compiler
    let l:compiler_line = a:compiler." ".a:compiler_args
    if a:compiler !=? "ant"
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
        elseif filereadable(l:path."/SConstruct")
            return [l:path, "scons"]
        else
            let l:path = fnamemodify(l:path, ":h")
        endif
    endwhile
    return []
endfunction
" }}}
function! shaihulud#CheckBuildCompleted(path, compiler) " {{{
    if exists("b:shaihulud_build_completed") && filereadable(expand(b:shaihulud_build_completed))
        execute "cd ".a:path
        if a:compiler ==? "ant"
            silent! execute "set errorformat=".g:shaihulud_errorformat_ant
        endif
        command! -buffer BuildErrors :silent execute 'cfile  '.b:shaihulud_build_error_file<bar>cwindow
        command! -buffer BuildWarnings :silent execute 'cfile  '.b:shaihulud_build_warnings_file<bar>cwindow
        execute "BuildErrors"

        if exists("g:shaihulud_build_completion_listeners") && len("g:shaihulud_build_completion_listeners") > 0
            for l in g:shaihulud_build_completion_listeners
                let Listener = function(l)
                call Listener()
            endfor
        endif

        unlet! b:shaihulud_build_completed
        autocmd! VimResized <buffer>
    endif
endfunction
" }}}
function! shaihulud#Build(...)
    "" Determine the path
    let l:build_args = ""
    if a:0 > 0
        let l:path = fnamemodify(a:1, ":p")
        if !isdirectory(l:path)
            let l:path = expand("%:p:h")
            let l:build_args = a:1." "
        endif

        if (a:0 > 1)
            let l:build_args .= join(a:000[1:], ' ')
        endif
    else
        let l:path = expand("%:p:h")
    endif

    "" Retrieve build framework info
    let l:build_info = []
    if exists("g:shaihulud_build_info_cache")
        if has_key(g:shaihulud_build_info_cache, l:path)
            let l:build_info = g:shaihulud_build_info_cache[l:path]
        endif
    else
        let g:shaihulud_build_info_cache = {}
    endif

    if len(l:build_info) == 0
        let l:build_info = shaihulud#GetBuildFramework(l:path)
        let g:shaihulud_build_info_cache[l:path] = l:build_info
    endif

    "" If we were able to determine build info, build the command and execute it
    if len(l:build_info) > 0
        let b:shaihulud_build_error_file = tempname()
        let b:shaihulud_build_warning_file = tempname()
        let b:shaihulud_build_completed = tempname()

        " execute "autocmd VimResized <buffer> call shaihulud#CheckBuildCompleted('".l:build_info[0]."')"
        execute "autocmd VimResized <buffer> call shaihulud#CheckBuildCompleted('".l:build_info[0]."', '".l:build_info[1]."')"

        let l:cmd = shaihulud#BuildCommand(l:build_info[0], l:build_info[1], l:build_args)
        execute "RunIn ".l:build_info[0]." ".l:cmd
    else
        echomsg "No clue what to build with"
    endif
endfunction

" vim: set foldmethod=marker formatoptions-=tc:
