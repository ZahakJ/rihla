-- Wraps plugin specs so every plugin's configuration runs inside util.safe:
-- if one plugin breaks (an upstream change, a missing tool), it reports itself
-- in one line and every other plugin still configures normally.
local util = require("rihla.util")

local M = {}

local function short(spec)
  local name = spec.name or spec[1] or spec.dir or "?"
  return (name:gsub("^.*/", ""))
end

local function wrap_one(spec)
  if type(spec) ~= "table" then
    return spec
  end
  local name = short(spec)
  local cfg = spec.config
  if type(cfg) == "function" then
    spec.config = function(plugin, opts)
      util.safe(name, cfg, plugin, opts)
    end
  elseif spec.opts ~= nil and cfg == nil and spec.main then
    local main = spec.main
    spec.config = function(_, opts)
      util.safe(name, function()
        require(main).setup(opts)
      end)
    end
  end
  if type(spec.dependencies) == "table" then
    for i, dep in ipairs(spec.dependencies) do
      spec.dependencies[i] = wrap_one(dep)
    end
  end
  return spec
end

--- wrap({ spec, spec, ... }) -> the same list, configs guarded.
function M.wrap(list)
  for i, spec in ipairs(list) do
    list[i] = wrap_one(spec)
  end
  return list
end

return M
