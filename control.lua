-- WePlay: Mr. Fusion
-- Burns items from the trash slots and/or a per-player filter list, and pours
-- the energy into the batteries of the wearer's equipment grid.

local NAME = "wp-mr-fusion"
local SHORTCUT = "wp-mr-fusion-shortcut"
local FRAME = "wp_mr_fusion_frame"
local TRASH_BOX = "wp_mr_fusion_trash"
local TABLE = "wp_mr_fusion_table"
local SLOT_PREFIX = "wp_mr_fusion_slot_"
local SLOTS = 20
local TICKS = 60 -- runs once a second

---------------------------------------------------------------------------
-- Player data
---------------------------------------------------------------------------

local function pdata(index)
  storage.players = storage.players or {}
  local d = storage.players[index]
  if not d then
    d = { filters = {}, use_trash = true, carry = 0 }
    storage.players[index] = d
  end
  return d
end

script.on_init(function()
  storage.players = {}
end)

script.on_configuration_changed(function()
  storage.players = storage.players or {}
end)

script.on_event(defines.events.on_player_removed, function(event)
  if storage.players then storage.players[event.player_index] = nil end
end)

---------------------------------------------------------------------------
-- Grid helpers
---------------------------------------------------------------------------

local function get_grid(player)
  local character = player.character
  if not (character and character.valid) then return nil end
  local inv = player.get_inventory(defines.inventory.character_armor)
  if not (inv and inv.valid and #inv > 0) then return nil end
  local armor = inv[1]
  if armor.valid_for_read then return armor.grid end
  return nil
end

-- Count Mr. Fusions and collect batteries that still have room.
local function scan(grid)
  local fusions, batteries, free = 0, {}, 0
  for _, eq in pairs(grid.equipment) do
    if eq.name == NAME then
      fusions = fusions + 1
    elseif eq.type == "battery-equipment" then
      local room = eq.max_energy - eq.energy
      if room > 0 then
        batteries[#batteries + 1] = eq
        free = free + room
      end
    end
  end
  return fusions, batteries, free
end

-- Pour energy into batteries; returns whatever didn't fit.
local function deposit(batteries, amount)
  for _, eq in pairs(batteries) do
    if amount <= 0 then break end
    if eq.valid then
      local room = eq.max_energy - eq.energy
      if room > 0 then
        local add = math.min(room, amount)
        eq.energy = eq.energy + add
        amount = amount - add
      end
    end
  end
  return amount
end

---------------------------------------------------------------------------
-- Burning
---------------------------------------------------------------------------

local function value_of(name)
  local proto = prototypes.item[name]
  local fuel = proto and proto.fuel_value or 0
  if fuel > 0 then
    return fuel * settings.global["wp-mr-fusion-fuel-efficiency"].value
  end
  return settings.global["wp-mr-fusion-junk-energy"].value * 1000
end

-- Never burn items that carry their own data (armor with equipment,
-- blueprints, items with inventories, etc.).
local function is_plain(stack)
  return stack.item_number == nil
end

-- Burns one item at a time until the budget runs out or the batteries are
-- full. Leftover energy from the last item is kept in d.carry for next time,
-- so a 1.21 GJ nuclear fuel cell is never wasted.
local function burn_from(inv, wanted, budget, batteries, d)
  if not (inv and inv.valid) then return budget end
  for i = 1, #inv do
    local stack = inv[i]
    while budget > 0 and d.carry <= 0 and stack.valid_for_read and wanted(stack) do
      local value = value_of(stack.name)
      if stack.count > 1 then
        stack.count = stack.count - 1
      else
        stack.clear()
      end
      budget = budget - 1
      d.carry = deposit(batteries, value)
    end
    if budget <= 0 or d.carry > 0 then break end
  end
  return budget
end

script.on_nth_tick(TICKS, function()
  local rate = settings.global["wp-mr-fusion-items-per-second"].value
  for _, player in pairs(game.connected_players) do
    local grid = get_grid(player)
    if grid then
      local fusions, batteries, free = scan(grid)
      if fusions > 0 and free > 0 then
        local d = pdata(player.index)
        d.carry = deposit(batteries, d.carry)
        if d.carry <= 0 then
          local budget = rate * fusions * (TICKS / 60)

          if d.use_trash then
            budget = burn_from(
              player.get_inventory(defines.inventory.character_trash),
              is_plain, budget, batteries, d)
          end

          if budget > 0 and d.carry <= 0 and next(d.filters) then
            burn_from(
              player.get_inventory(defines.inventory.character_main),
              function(stack) return d.filters[stack.name] and is_plain(stack) end,
              budget, batteries, d)
          end
        end
      end
    end
  end
end)

---------------------------------------------------------------------------
-- Filter GUI (opened from the shortcut bar)
---------------------------------------------------------------------------

local function close_gui(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then frame.destroy() end
end

local function open_gui(player)
  close_gui(player)
  local d = pdata(player.index)

  local frame = player.gui.screen.add{
    type = "frame", name = FRAME, direction = "vertical",
    caption = { "wp-mr-fusion.gui-title" }
  }
  frame.auto_center = true

  frame.add{
    type = "checkbox", name = TRASH_BOX, state = d.use_trash,
    caption = { "wp-mr-fusion.use-trash" },
    tooltip = { "wp-mr-fusion.use-trash-tooltip" }
  }
  frame.add{ type = "label", caption = { "wp-mr-fusion.filters" } }

  local names = {}
  for name in pairs(d.filters) do names[#names + 1] = name end
  table.sort(names)

  local tbl = frame.add{ type = "table", name = TABLE, column_count = 10 }
  for i = 1, SLOTS do
    tbl.add{
      type = "choose-elem-button", name = SLOT_PREFIX .. i,
      elem_type = "item", item = names[i]
    }
  end

  player.opened = frame
end

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= SHORTCUT then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  if player.gui.screen[FRAME] then
    close_gui(player)
  else
    open_gui(player)
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if element and element.valid and element.name == FRAME then
    element.destroy()
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  if element.name ~= TRASH_BOX then return end
  pdata(event.player_index).use_trash = element.state
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element
  if not (element.parent and element.parent.name == TABLE) then return end
  local d = pdata(event.player_index)
  d.filters = {}
  for _, child in pairs(element.parent.children) do
    if child.elem_value then d.filters[child.elem_value] = true end
  end
end)
