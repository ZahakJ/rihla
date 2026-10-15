-- The numbered tabs along the top (bufferline.nvim): which number each tab
-- shows, Alt-N / Space N, and closing the other tabs.
--
-- bufferline numbers tabs before moving pinned ones to the left, so with
-- numbers = "ordinal" the bar can read "2. 3. 1. 4." while go_to() counts from
-- the left. Here the number is the tab's place in bufferline's own order (pinned
-- first), and Alt-N / Space N use the same list.
local M = {}

local function pinned(id)
  local ok, groups = pcall(require, "bufferline.groups")
  return ok and groups._is_pinned({ id = id }) or false
end

--- Buffer ids in the order the bar shows them.
function M.order()
  local ok, utils = pcall(require, "bufferline.utils")
  if not ok then
    return {}
  end
  local bufs = utils.get_valid_buffers()
  -- bufferline's order: the one set by moving tabs (custom_sort), else buffer number;
  -- tabs it has not seen yet go after the sorted ones.
  local rank = {}
  local sorted = require("bufferline.state").custom_sort
  for i, id in ipairs(sorted or {}) do
    rank[id] = i
  end
  table.sort(bufs, function(a, b)
    local ra, rb = rank[a], rank[b]
    if ra and rb then
      return ra < rb
    elseif ra or rb then
      return ra ~= nil
    end
    return a < b
  end)
  local first, rest = {}, {}
  for _, id in ipairs(bufs) do
    table.insert(pinned(id) and first or rest, id)
  end
  return vim.list_extend(first, rest)
end

--- bufferline `numbers` option: the tab's place from the left.
function M.number(opts)
  for i, id in ipairs(M.order()) do
    if id == opts.id then
      return tostring(i) .. "."
    end
  end
  return tostring(opts.ordinal) .. "."
end

--- Alt-N / Space N: the tab numbered N (the last one if there are fewer).
function M.go(n)
  local list = M.order()
  local id = list[n] or list[#list]
  if id and vim.api.nvim_buf_is_valid(id) then
    vim.api.nvim_set_current_buf(id)
  end
end

--- Space b o: close every other tab except pinned ones and ones with unsaved
--- changes (VS Code's Close Others keeps pinned tabs, and asks about unsaved ones).
function M.close_others()
  local cur = vim.api.nvim_get_current_buf()
  local kept_pinned, kept_modified, closed = 0, 0, 0
  for _, id in ipairs(M.order()) do
    if id ~= cur then
      if pinned(id) then
        kept_pinned = kept_pinned + 1
      elseif vim.bo[id].modified then
        kept_modified = kept_modified + 1
      else
        local ok = pcall(require("mini.bufremove").delete, id, false)
        if not ok then
          ok = pcall(vim.api.nvim_buf_delete, id, {})
        end
        closed = closed + (ok and 1 or 0)
      end
    end
  end
  local kept = {}
  if kept_pinned > 0 then
    kept[#kept + 1] = ("%d pinned"):format(kept_pinned)
  end
  if kept_modified > 0 then
    kept[#kept + 1] = ("%d with unsaved changes (save with :w, or close with Space b D)"):format(kept_modified)
  end
  local msg = ("Closed %d tab(s)."):format(closed)
  if #kept > 0 then
    msg = msg .. " Kept " .. table.concat(kept, " and ") .. "."
  end
  vim.api.nvim_echo({ { msg } }, false, {})
end

return M
