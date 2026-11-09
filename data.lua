local GFX = "__WePlayMrFusion__/graphics/"
local ICON = GFX .. "mr-fusion-icon.png"

-- The equipment itself holds no energy. control.lua pours the burned items'
-- energy straight into the other batteries in the grid (same trick as the
-- lightning rod), so nothing can charge or drain it.
local equipment = {
  type = "battery-equipment",
  name = "wp-mr-fusion",
  sprite = {
    filename = GFX .. "mr-fusion-equipment.png",
    width = 128,
    height = 256,
    priority = "medium",
    scale = 0.5
  },
  -- 1x2 so the tall reactor fits the grid without squishing
  shape = { width = 1, height = 2, type = "full" },
  energy_source = {
    type = "electric",
    buffer_capacity = "0J",
    usage_priority = "tertiary",
    input_flow_limit = "0W",
    output_flow_limit = "0W"
  },
  categories = { "armor" }
}

local battery_item = data.raw.item["battery-equipment"]

local item = {
  type = "item",
  name = "wp-mr-fusion",
  icon = ICON,
  icon_size = 64,
  place_as_equipment_result = "wp-mr-fusion",
  subgroup = battery_item and battery_item.subgroup or "equipment",
  order = "a[energy-source]-a[wp-mr-fusion]",
  stack_size = 20
}

local recipe = {
  type = "recipe",
  name = "wp-mr-fusion",
  enabled = false,
  energy_required = 5,
  ingredients = {
    { type = "item", name = "stone-furnace", amount = 1 },
    { type = "item", name = "iron-plate", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 }
  },
  results = { { type = "item", name = "wp-mr-fusion", amount = 1 } }
}

local shortcut = {
  type = "shortcut",
  name = "wp-mr-fusion-shortcut",
  action = "lua",
  icon = ICON,
  icon_size = 64,
  small_icon = ICON,
  small_icon_size = 64
}

data:extend({ equipment, item, recipe, shortcut })

local tech = data.raw.technology["modular-armor"]
if tech then
  tech.effects = tech.effects or {}
  table.insert(tech.effects, { type = "unlock-recipe", recipe = "wp-mr-fusion" })
else
  recipe.enabled = true
end
