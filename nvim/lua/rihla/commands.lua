-- :Rihla <subcommand>, and the <leader>h "help / learn" keys.
local util = require("rihla.util")

local M = {}

local function doc(name)
  return util.docs .. "/" .. name
end

M.sub = {}

M.sub.cheat = {
  desc = "Neovim cheat sheet",
  run = function()
    require("rihla.ui").float_file(doc("cheatsheet-nvim.md"), "rihla cheat sheet")
  end,
}
M.sub.tmux = {
  desc = "tmux cheat sheet",
  run = function()
    require("rihla.ui").float_file(doc("cheatsheet-tmux.md"), "tmux cheat sheet")
  end,
}
M.sub.vscode = {
  desc = "VS Code -> Neovim table (`:Rihla vscode search` for a picker)",
  args = { "search" },
  run = function(args)
    if args[1] == "search" then
      require("rihla.cheat").vscode_picker()
    else
      require("rihla.ui").float_file(doc("vscode-to-neovim.md"), "VS Code -> Neovim")
    end
  end,
}
M.sub.learn = {
  desc = "Open the current lesson; learn next|prev|done|list|reset|file|split|<number>",
  args = { "next", "prev", "done", "list", "reset", "file", "split" },
  run = function(args)
    require("rihla.learn").command(args)
  end,
}
M.sub.tip = {
  desc = "Show a tip from the curriculum",
  run = function()
    local tip = require("rihla.learn").tip(true)
    vim.notify(tip or "No tips found", vim.log.levels.INFO, { title = "rihla tip" })
  end,
}
M.sub.home = {
  desc = "Lost? Back to your lesson, in one window (Space h h)",
  run = function()
    require("rihla.learn").home()
  end,
}
M.sub.check = {
  desc = "Check what works on this machine (:checkhealth rihla)",
  run = function()
    vim.cmd("checkhealth rihla")
  end,
}
M.sub.langs = {
  desc = "Languages: parser, server, formatter, linter, debugger status",
  run = function()
    require("rihla.health").langs_float()
  end,
}
M.sub.install = {
  desc = "Install tools for languages now: install <lang>... | all (headless: waits)",
  complete = function()
    local names = vim.tbl_keys(require("rihla.lang").langs)
    table.sort(names)
    table.insert(names, 1, "all")
    return names
  end,
  run = function(args)
    local lang = require("rihla.lang")
    local targets = {}
    if #args == 0 then
      local e = lang.by_ft[vim.bo.filetype]
      if e then
        targets = { e }
      end
    end
    for _, a in ipairs(args) do
      if a == "all" then
        targets = vim.tbl_values(lang.langs)
        break
      end
      if lang.langs[a] then
        table.insert(targets, lang.langs[a])
      else
        vim.notify("rihla: unknown language '" .. a .. "' (see :Rihla langs)", vim.log.levels.WARN)
      end
    end
    if #targets == 0 then
      vim.notify("rihla: usage :Rihla install <language>... | all", vim.log.levels.INFO)
      return
    end
    for _, e in ipairs(targets) do
      lang.ensure(e, { force = true, with_dap = vim.tbl_contains(args, "all") == false })
    end
    if #vim.api.nvim_list_uis() == 0 then
      -- Headless (installer pre-seeding): wait for the background jobs.
      vim.wait(100)
      require("rihla.tools").wait()
      io.stdout:write("rihla: install finished\n")
    end
  end,
}
M.sub.sync = {
  desc = "Make plugins match the lockfile (used by `rihla update`)",
  run = function()
    require("rihla.lazy").sync()
    if #vim.api.nvim_list_uis() == 0 then
      io.stdout:write("rihla: plugins match the lockfile\n")
    end
  end,
}
M.sub.habits = {
  desc = "Habit hints: habits off|hint|strict",
  args = { "off", "hint", "strict" },
  run = function(args)
    require("rihla.habits").set(args[1])
  end,
}
M.sub.icons = {
  desc = "Icon set: icons nerd|ascii (saved, applies on restart)",
  args = { "nerd", "ascii" },
  run = function(args)
    local mode = args[1]
    if mode ~= "nerd" and mode ~= "ascii" then
      vim.notify("rihla: icons are '" .. vim.g.rihla_icons .. "'. Use :Rihla icons nerd|ascii")
      return
    end
    util.write(util.user_dir .. "/icons", mode .. "\n")
    vim.notify("rihla: icons set to " .. mode .. "; restart Neovim (and run `tmux source ~/.tmux.conf`)")
  end,
}
M.sub.log = {
  desc = "Open rihla's log (full errors behind one-line messages)",
  run = function()
    local log = vim.fn.stdpath("log") .. "/rihla.log"
    if vim.fn.filereadable(log) == 0 then
      util.say("rihla: the log is empty: nothing has gone wrong yet.")
      return
    end
    local win = require("rihla.ui").float_file(log, "rihla log")
    if win then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win)), 0 })
    end
  end,
}
M.sub.palette = {
  desc = "Command palette",
  run = function()
    require("rihla.cmdpalette").open()
  end,
}
M.sub.version = {
  desc = "Show rihla and Neovim versions",
  run = function()
    local v = vim.version()
    local rev = vim.trim(vim.fn.system({ "git", "-C", util.root, "describe", "--tags", "--always", "--dirty" }) or "")
    if vim.v.shell_error ~= 0 then
      rev = vim.trim(util.read(util.root .. "/VERSION") or "unknown")
    end
    vim.notify(("rihla %s, Neovim %d.%d.%d, icons: %s"):format(rev, v.major, v.minor, v.patch, vim.g.rihla_icons))
  end,
}

function M.run(opts)
  local args = vim.split(opts.args or "", "%s+", { trimempty = true })
  local name = table.remove(args, 1) or "help"
  local sub = M.sub[name]
  if not sub then
    local lines = {}
    local names = vim.tbl_keys(M.sub)
    table.sort(names)
    for _, n in ipairs(names) do
      lines[#lines + 1] = (" :Rihla %-8s %s"):format(n, M.sub[n].desc)
    end
    require("rihla.ui").float_lines(lines, "rihla commands")
    return
  end
  util.safe("Rihla " .. name, sub.run, args)
end

function M.complete(arglead, cmdline)
  local words = vim.split(cmdline, "%s+", { trimempty = false })
  if #words <= 2 then
    local names = vim.tbl_keys(M.sub)
    table.sort(names)
    return vim.tbl_filter(function(n)
      return n:find(arglead, 1, true) == 1
    end, names)
  end
  local sub = M.sub[words[2]]
  if not sub then
    return {}
  end
  local opts = sub.complete and sub.complete() or sub.args or {}
  return vim.tbl_filter(function(n)
    return n:find(arglead, 1, true) == 1
  end, opts)
end

function M.setup()
  vim.api.nvim_create_user_command("Rihla", M.run, { nargs = "*", complete = M.complete, desc = "rihla: lessons, help, check, languages" })

  local map = util.map
  local function cmd(s)
    return function()
      M.run({ args = s })
    end
  end
  map("n", "<leader>hc", cmd("cheat"), "Cheat sheet (Neovim)")
  map("n", "<leader>hT", cmd("tmux"), "Cheat sheet (tmux)")
  map("n", "<leader>hv", cmd("vscode search"), "VS Code -> Neovim: search the table")
  map("n", "<leader>hV", cmd("vscode"), "VS Code -> Neovim: read the table")
  map("n", "<leader>hh", cmd("home"), "Lost? Back to the lesson, one window")
  map("n", "<leader>hl", cmd("learn"), "Current lesson")
  map("n", "<leader>hn", cmd("learn next"), "Lesson done: go to the next")
  map("n", "<leader>hp", cmd("learn prev"), "Previous lesson")
  map("n", "<leader>hd", cmd("learn done"), "Mark this lesson done")
  map("n", "<leader>hL", cmd("learn list"), "All lessons and your progress")
  map("n", "<leader>hr", cmd("learn reset"), "Reset this lesson (a fresh copy)")
  map("n", "<leader>hf", cmd("learn file"), "Open this lesson's practice file")
  map("n", "<leader>ht", "<cmd>Tutor<CR>", "Vim tutor (in lesson 0)")
  map("n", "<leader>hi", cmd("tip"), "Tip from the curriculum")
  map("n", "<leader>hC", cmd("check"), "Check: what works on this machine")
  map("n", "<leader>lL", cmd("langs"), "Languages: what is installed")
  map("n", "<leader>th", function()
    require("rihla.habits").cycle()
  end, "Habit hints: cycle off / hint / strict")
end

return M
