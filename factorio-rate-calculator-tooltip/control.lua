local rate_math = require("rate-math")

local gui_name = "frc_live_rates_frame"
local live_tooltip_time_unit_setting_name = "factorio-rate-calculator-tooltip-live-tooltip-time-unit"
local max_rate_entries_per_field = 4
local live_gui_width = 330
local game_side_panel_width = 315
local live_gui_side_gap = 2
local live_gui_top_margin = 18

local craft_entity_types = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true,
}

local function init_storage()
  storage.players = storage.players or {}
end

local function get_recipe(player, entity)
  local recipe = entity.get_recipe and entity.get_recipe()

  if recipe then
    return recipe
  end

  if entity.type == "furnace" and entity.previous_recipe then
    local previous_recipe_prototype = entity.previous_recipe.name

    if previous_recipe_prototype and previous_recipe_prototype.name then
      return player.force.recipes[previous_recipe_prototype.name]
    end
  end

  return nil
end

local function get_productivity_multiplier(entity, recipe)
  local recipe_productivity = recipe.productivity_bonus or 0
  local maximum_productivity = recipe.prototype.maximum_productivity or 0
  local productivity_bonus = (entity.productivity_bonus or 0) + recipe_productivity

  return 1 + math.min(productivity_bonus, maximum_productivity)
end

local function get_display_time_unit(player)
  local player_settings = settings.get_player_settings(player.index)
  local time_unit_setting = player_settings[live_tooltip_time_unit_setting_name]

  if time_unit_setting then
    return time_unit_setting.value
  end

  return "minute"
end

local function add_rate_line(parent, prototype_type, prototype_name, rate, display_time_unit)
  parent.add({
    type = "label",
    caption = {
      "",
      rate_math.get_rich_text_icon(prototype_type, prototype_name),
      " ",
      rate_math.format_rate(rate, display_time_unit),
    },
  })
end

local function add_ingredient_rates(parent, recipe, crafts_per_second, display_time_unit)
  parent.add({ type = "label", caption = { "factorio-rate-calculator-tooltip.input-label" } })

  local rates_flow = parent.add({ type = "flow", direction = "vertical" })
  local displayed_entries = 0

  for _, ingredient in pairs(recipe.ingredients or {}) do
    local prototype_name = rate_math.get_prototype_name(ingredient)

    if prototype_name then
      add_rate_line(
        rates_flow,
        rate_math.get_prototype_type(ingredient),
        prototype_name,
        rate_math.get_ingredient_amount(ingredient) * crafts_per_second,
        display_time_unit
      )
      displayed_entries = displayed_entries + 1
    end
  end

  if displayed_entries == 0 then
    rates_flow.add({ type = "label", caption = "-" })
  end
end

local function add_product_rates(parent, entity, recipe, crafts_per_second, display_time_unit)
  parent.add({ type = "label", caption = { "factorio-rate-calculator-tooltip.output-label" } })

  local rates_flow = parent.add({ type = "flow", direction = "vertical" })
  local displayed_entries = 0
  local productivity_multiplier = get_productivity_multiplier(entity, recipe)

  for _, product in pairs(recipe.products or {}) do
    local prototype_name = rate_math.get_prototype_name(product)

    if prototype_name then
      if displayed_entries >= max_rate_entries_per_field then
        rates_flow.add({ type = "label", caption = "..." })
        break
      end

      add_rate_line(
        rates_flow,
        rate_math.get_prototype_type(product),
        prototype_name,
        rate_math.get_product_amount_with_productivity(product, productivity_multiplier) * crafts_per_second,
        display_time_unit
      )
      displayed_entries = displayed_entries + 1
    end
  end

  if displayed_entries == 0 then
    rates_flow.add({ type = "label", caption = "-" })
  end
end

local function destroy_gui(player)
  local frame = player.gui.screen[gui_name]

  if frame then
    frame.destroy()
  end
end

local function get_screen_gui_location(player)
  local resolution = player.display_resolution
  local scale = player.display_scale

  return {
    x = math.max(0, resolution.width - ((game_side_panel_width + live_gui_width + live_gui_side_gap) * scale)),
    y = math.max(0, live_gui_top_margin * scale),
  }
end

local function build_gui(player, entity, recipe, display_time_unit)
  destroy_gui(player)

  local craft_time = recipe.energy or 0.5
  local crafting_speed = entity.crafting_speed or 1
  local crafts_per_second = crafting_speed / craft_time

  local frame = player.gui.screen.add({
    type = "frame",
    name = gui_name,
    direction = "vertical",
    caption = { "factorio-rate-calculator-tooltip.live-rates-title", "[entity=" .. entity.name .. "]" },
  })
  frame.style.width = live_gui_width
  frame.location = get_screen_gui_location(player)

  frame.add({
    type = "label",
    caption = {
      "factorio-rate-calculator-tooltip.recipe-label",
      recipe.prototype.localised_name or { "recipe-name." .. recipe.name },
    },
  })
  frame.add({
    type = "label",
    caption = { "factorio-rate-calculator-tooltip.speed-label", rate_math.format_number(crafting_speed) },
  })
  frame.add({ type = "line", direction = "horizontal" })
  add_ingredient_rates(frame, recipe, crafts_per_second, display_time_unit)
  add_product_rates(frame, entity, recipe, crafts_per_second, display_time_unit)
end

local function get_selected_key(entity, recipe, display_time_unit)
  return table.concat({
    entity.unit_number or 0,
    entity.name,
    recipe.name,
    entity.crafting_speed or 1,
    entity.productivity_bonus or 0,
    display_time_unit,
  }, ":")
end

local function update_player(player)
  local player_data = storage.players[player.index] or {}
  storage.players[player.index] = player_data

  local entity = player.selected

  if not entity or not entity.valid or not craft_entity_types[entity.type] then
    if player_data.selected_key then
      destroy_gui(player)
      player_data.selected_key = nil
    end

    return
  end

  local recipe = get_recipe(player, entity)

  if not recipe then
    if player_data.selected_key then
      destroy_gui(player)
      player_data.selected_key = nil
    end

    return
  end

  local display_time_unit = get_display_time_unit(player)
  local selected_key = get_selected_key(entity, recipe, display_time_unit)

  if player_data.selected_key == selected_key then
    return
  end

  player_data.selected_key = selected_key
  build_gui(player, entity, recipe, display_time_unit)
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

script.on_event(defines.events.on_tick, function(event)
  if event.tick % 15 ~= 0 then
    return
  end

  init_storage()

  for _, player in pairs(game.connected_players) do
    update_player(player)
  end
end)
