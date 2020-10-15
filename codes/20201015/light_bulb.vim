
" Inspired to an article (https://rust-analyzer.github.io/blog/2020/09/28/how-to-make-a-light-bulb.html)
" This script implementes light bulb system using language server's code
" action
"
" Require vim-lsp
"
" call sign_place(10, 'MySignGroup', 'MySign', '%', {'lnum' : 1, 'priority' : 90
" call sign_unplace("MySignGroup")

call sign_define('MySign', {"text": "💡"})

function! Do(option) abort
    let l:selection = get(a:option, 'selection', v:false)
    let l:sync = get(a:option, 'sync', v:false)
    let l:query = get(a:option, 'query', '')

    let l:server_names = filter(lsp#get_allowed_servers(), 'lsp#capabilities#has_code_action_provider(v:val)')
    if len(l:server_names) == 0
        return lsp#utils#error('Code action not supported for ' . &filetype)
    endif

    let l:range = {
        \ "start": {"character": 0, "line": 0},
        \ "end": {"character": 0, "line": line('$')},
        \ }

    let l:ctx = {
    \ 'count': len(l:server_names),
    \ 'results': [],
    \}
    let l:bufnr = bufnr('%')
    let l:command_id = lsp#_new_command()
    for l:server_name in l:server_names
        let l:diagnostic = lsp#ui#vim#diagnostics#get_diagnostics_under_cursor(l:server_name)
        call lsp#send_request(l:server_name, {
                    \ 'method': 'textDocument/codeAction',
                    \ 'params': {
                    \   'textDocument': lsp#get_text_document_identifier(),
                    \   'range': l:range,
                    \   'context': {
                    \       'diagnostics' : [],
                    \       'only': ['', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline', 'refactor.rewrite', 'source', 'source.organizeImports'],
                    \   },
                    \ },
                    \ 'sync': l:sync,
                    \ 'on_notification': function('s:handle', [l:ctx, l:server_name, l:command_id, l:sync, l:query, l:bufnr]),
                    \ })
    endfor
    echo 'Retrieving code actions ...'
endfunction

function! s:handle(ctx, server_name, command_id, sync, query, bufnr, data) abort
    " Ignore old request.
    if a:command_id != lsp#_last_command()
        return
    endif

    call add(a:ctx['results'], {
    \    'server_name': a:server_name,
    \    'data': a:data,
    \})
    let a:ctx['count'] -= 1
    if a:ctx['count'] ># 0
        return
    endif
    
    let l:total_code_actions = []

    for l:result in a:ctx['results']
        let l:server_name = l:result['server_name']
        let l:data = l:result['data']
        " Check response error.
        if lsp#client#is_error(l:data['response'])
            call lsp#utils#error('Failed to CodeAction for ' . l:server_name . ': ' . lsp#client#error_message(l:data['response']))
            continue
        endif

        " Check code actions.
        let l:code_actions = l:data['response']['result']


        " Filter code actions.
        if !empty(a:query)
            let l:code_actions = filter(l:code_actions, { _, action -> get(action, 'kind', '') =~# '^' . a:query })
        endif
        if empty(l:code_actions)
            continue
        endif

        for l:code_action in l:code_actions
            let l:changes = l:code_action["edit"]["changes"]

            for [l:fname, l:actions] in items(l:changes)
                for action in l:actions
                    let lnum = l:action["range"]["start"]["line"] + 1
                    call sign_place(lnum, l:server_name, 'MySign', '%', {'lnum' : lnum, 'priority' : 100})
                endfor
            endfor
        endfor
    endfor

    " " Execute code action.
    " if 0 < l:index && l:index <= len(l:total_code_actions)
    "     let l:selected = l:total_code_actions[l:index - 1]
    "     call s:handle_one_code_action(l:selected['server_name'], a:sync, a:bufnr, l:selected['code_action'])
    " endif
endfunction

