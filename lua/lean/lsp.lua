local lsp = { handlers = {} }

function lsp.enable(opts)
  opts.commands = vim.tbl_extend("keep", opts.commands or {}, {
    LeanPlainGoal = {
      function (...) lsp.plain_goal(vim.lsp.util.make_position_params(), ...) end;
      description = "Describe the current tactic state."
    };
    LeanPlainTermGoal = {
      function (...) lsp.plain_term_goal(vim.lsp.util.make_position_params(), ...) end;
      description = "Describe the expected type of the current term."
    };
  })
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ["$/lean/plainGoal"] = lsp.handlers.plain_goal_handler;
    ["$/lean/plainTermGoal"] = lsp.handlers.plain_term_goal_handler;
    ['$/lean/fileProgress'] = lsp.handlers.file_progress_handler;
    ['textDocument/publishDiagnostics'] = lsp.handlers.diagnostics_handler;
  })
  require('lspconfig').leanls.setup(opts)
end

-- Fetch goal state information from the server.
function lsp.plain_goal(params, bufnr, handler)
  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  return vim.lsp.buf_request(bufnr, "$/lean/plainGoal", params, handler)
end

-- Fetch term goal state information from the server.
function lsp.plain_term_goal(params, bufnr, handler)
  params = vim.deepcopy(params)
  return vim.lsp.buf_request(bufnr, "$/lean/plainTermGoal", params, handler)
end

function lsp.handlers.plain_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.rendered) then
    return
  end
  local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.rendered)
  markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    return
  end
  return vim.lsp.util.open_floating_preview(markdown_lines, "markdown", config)
end

function lsp.handlers.plain_term_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.goal) then
    return
  end
  return vim.lsp.util.open_floating_preview(
    vim.split(result.goal, '\n'), "leaninfo", config
  )
end

function lsp.handlers.file_progress_handler(err, _, params, _, _, _)
  if err ~= nil then return end

  require"lean.progress".update(params)

  require"lean.infoview".__update_event(params.textDocument.uri)

  require"lean.progress_bars".update(params)
end

function lsp.handlers.diagnostics_handler (err, method, params, client_id, bufnr, config)
  require"vim.lsp.handlers"['textDocument/publishDiagnostics'](err, method, params, client_id, bufnr, config)

  require"lean.infoview".__update_event(params.uri)
end

return lsp
