local rate_math = require("rate-math")

local gui_name = "frc_live_rates_frame"
local live_tooltip_time_unit_setting_name = "factorio-rate-calculator-tooltip-live-tooltip-time-unit"
local show_belt_fill_targets_setting_name = "factorio-rate-calculator-tooltip-show-belt-fill-targets"
local max_rate_entries_per_field = 4
local live_gui_width = 330
local game_side_panel_width = 315
local live_gui_side_gap = 2
local live_gui_top_margin = 18

local transport_belts = {
  {
    capacity_per_second = 15,
    icon = "[entity=transport-belt]",
    label = { "factorio-rate-calculator-tooltip.yellow-belt-label" },
  },
  {
    capacity_per_second = 30,
    icon = "[entity=fast-transport-belt]",
    label = { "factorio-rate-calculator-tooltip.red-belt-label" },
  },
  {
    capacity_per_second = 45,
    icon = "[entity=express-transport-belt]",
    label = { "factorio-rate-calculator-tooltip.blue-belt-label" },
  },
}

local craft_entity_types = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["mining-drill"] = true,
  ["rocket-silo"] = true,
}

local function init_storage()
  storage.players = storage.players or {}
end

local function get_recipe_id_name(recipe_id)
  if not recipe_id then
    return nil
  end

  if type(recipe_id) == "string" then
    return recipe_id
  end

  return recipe_id.name
end

local function get_previous_recipe_name(entity)
  local previous_recipe = entity.previous_recipe

  if not previous_recipe then
    return nil
  end

  if type(previous_recipe) == "table" then
    return get_recipe_id_name(previous_recipe.name)
  end

  return get_recipe_id_name(previous_recipe)
end

local function get_recipe(player, entity)
  local recipe = entity.get_recipe and entity.get_recipe()

  if recipe then
    return recipe
  end

  if entity.type == "furnace" and entity.previous_recipe then
    local previous_recipe_name = get_previous_recipe_name(entity)

    if previous_recipe_name then
      return player.force.recipes[previous_recipe_name]
    end
  end

  return nil
end

local function get_entity_productivity_bonus(entity)
  local success, productivity_bonus = pcall(function()
    return entity.productivity_bonus
  end)

  if success then
    return productivity_bonus or 0
  end

  return 0
end

local function get_force_mining_productivity_bonus(force)
  local success, productivity_bonus = pcall(function()
    return force.mining_drill_productivity_bonus
  end)

  if success then
    return productivity_bonus or 0
  end

  return 0
end

local function get_productivity_multiplier(entity, recipe)
  local recipe_productivity = recipe.productivity_bonus or 0
  local maximum_productivity = recipe.prototype.maximum_productivity or 0
  local productivity_bonus = get_entity_productivity_bonus(entity) + recipe_productivity

  return 1 + math.min(productivity_bonus, maximum_productivity)
end

local function get_mining_productivity_multiplier(player, entity)
  return 1 + get_entity_productivity_bonus(entity) + get_force_mining_productivity_bonus(player.force)
end

local function get_mining_speed(entity)
  return (entity.prototype and entity.prototype.mining_speed) or 1
end

local function get_mining_ingredients(mineable_properties)
  if mineable_properties.required_fluid and mineable_properties.fluid_amount then
    return {
      {
        type = "fluid",
        name = mineable_properties.required_fluid,
        amount = mineable_properties.fluid_amount,
      },
    }
  end

  return {}
end

local function get_mining_products(mineable_properties)
  return mineable_properties.products or {}
end

local function get_crafting_rate_context(player, entity)
  local recipe = get_recipe(player, entity)

  if not recipe then
    return nil
  end

  local crafting_speed = entity.crafting_speed or 1

  return {
    key = recipe.name,
    subject_caption = { "factorio-rate-calculator-tooltip.recipe-label", recipe.prototype.localised_name or { "recipe-name." .. recipe.name } },
    speed = crafting_speed,
    operations_per_second = crafting_speed / (recipe.energy or 0.5),
    ingredients = recipe.ingredients or {},
    products = recipe.products or {},
    productivity_multiplier = get_productivity_multiplier(entity, recipe),
  }
end

local function get_mining_rate_context(player, entity)
  local mining_target = entity.mining_target

  if not mining_target or not mining_target.valid then
    return nil
  end

  local mineable_properties = mining_target.prototype.mineable_properties

  if not mineable_properties then
    return nil
  end

  local mining_speed = get_mining_speed(entity)

  return {
    key = mining_target.name,
    subject_caption = {
      "factorio-rate-calculator-tooltip.resource-label",
      mining_target.prototype.localised_name or { "entity-name." .. mining_target.name },
    },
    speed = mining_speed,
    operations_per_second = mining_speed / (mineable_properties.mining_time or 1),
    ingredients = get_mining_ingredients(mineable_properties),
    products = get_mining_products(mineable_properties),
    productivity_multiplier = get_mining_productivity_multiplier(player, entity),
  }
end

local function get_rate_context(player, entity)
  if entity.type == "mining-drill" then
    return get_mining_rate_context(player, entity)
  end

  return get_crafting_rate_context(player, entity)
end

local function get_display_time_unit(player)
  local player_settings = settings.get_player_settings(player.index)
  local time_unit_setting = player_settings[live_tooltip_time_unit_setting_name]

  if time_unit_setting then
    return time_unit_setting.value
  end

  return "minute"
end

local function should_show_belt_fill_targets(player)
  local player_settings = settings.get_player_settings(player.index)
  local show_setting = player_settings[show_belt_fill_targets_setting_name]

  if show_setting then
    return show_setting.value
  end

  return true
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

local function add_ingredient_rates(parent, ingredients, operations_per_second, display_time_unit)
  parent.add({ type = "label", caption = { "factorio-rate-calculator-tooltip.input-label" } })

  local rates_flow = parent.add({ type = "flow", direction = "vertical" })
  local displayed_entries = 0

  for _, ingredient in pairs(ingredients or {}) do
    local prototype_name = rate_math.get_prototype_name(ingredient)

    if prototype_name then
      add_rate_line(
        rates_flow,
        rate_math.get_prototype_type(ingredient),
        prototype_name,
        rate_math.get_ingredient_amount(ingredient) * operations_per_second,
        display_time_unit
      )
      displayed_entries = displayed_entries + 1
    end
  end

  if displayed_entries == 0 then
    rates_flow.add({ type = "label", caption = "-" })
  end
end

local function add_product_rates(parent, products, productivity_multiplier, operations_per_second, display_time_unit)
  parent.add({ type = "label", caption = { "factorio-rate-calculator-tooltip.output-label" } })

  local rates_flow = parent.add({ type = "flow", direction = "vertical" })
  local displayed_entries = 0

  for _, product in pairs(products or {}) do
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
        rate_math.get_product_amount_with_productivity(product, productivity_multiplier) * operations_per_second,
        display_time_unit
      )
      displayed_entries = displayed_entries + 1
    end
  end

  if displayed_entries == 0 then
    rates_flow.add({ type = "label", caption = "-" })
  end
end

local function add_belt_fill_target_line(parent, product_icon, belt, product_rate_per_second)
  local machine_count = belt.capacity_per_second / product_rate_per_second

  parent.add({
    type = "label",
    caption = {
      "factorio-rate-calculator-tooltip.belt-fill-target-line",
      product_icon,
      belt.icon,
      belt.label,
      rate_math.format_number(machine_count),
    },
  })
end

local function add_belt_fill_targets(parent, products, productivity_multiplier, operations_per_second)
  parent.add({ type = "label", caption = { "factorio-rate-calculator-tooltip.belt-fill-targets-label" } })

  local targets_flow = parent.add({ type = "flow", direction = "vertical" })
  local displayed_entries = 0

  for _, product in pairs(products or {}) do
    if rate_math.get_prototype_type(product) == "item" then
      local prototype_name = rate_math.get_prototype_name(product)

      if prototype_name then
        local product_rate_per_second =
          rate_math.get_product_amount_with_productivity(product, productivity_multiplier) * operations_per_second

        if product_rate_per_second > 0 then
          if displayed_entries >= max_rate_entries_per_field then
            targets_flow.add({ type = "label", caption = "..." })
            break
          end

          local product_icon = rate_math.get_rich_text_icon("item", prototype_name)

          for _, belt in ipairs(transport_belts) do
            add_belt_fill_target_line(targets_flow, product_icon, belt, product_rate_per_second)
          end

          displayed_entries = displayed_entries + 1
        end
      end
    end
  end

  if displayed_entries == 0 then
    targets_flow.add({ type = "label", caption = "-" })
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

local function build_gui(player, entity, rate_context, display_time_unit, show_belt_fill_targets)
  destroy_gui(player)

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
    caption = rate_context.subject_caption,
  })
  frame.add({
    type = "label",
    caption = { "factorio-rate-calculator-tooltip.speed-label", rate_math.format_number(rate_context.speed) },
  })
  frame.add({ type = "line", direction = "horizontal" })
  add_ingredient_rates(frame, rate_context.ingredients, rate_context.operations_per_second, display_time_unit)
  add_product_rates(
    frame,
    rate_context.products,
    rate_context.productivity_multiplier,
    rate_context.operations_per_second,
    display_time_unit
  )

  if show_belt_fill_targets then
    frame.add({ type = "line", direction = "horizontal" })
    add_belt_fill_targets(
      frame,
      rate_context.products,
      rate_context.productivity_multiplier,
      rate_context.operations_per_second
    )
  end
end

local function get_selected_key(entity, rate_context, display_time_unit, show_belt_fill_targets)
  return table.concat({
    entity.unit_number or 0,
    entity.name,
    entity.type,
    rate_context.key,
    rate_context.speed,
    rate_context.operations_per_second,
    get_entity_productivity_bonus(entity),
    rate_context.productivity_multiplier,
    display_time_unit,
    tostring(show_belt_fill_targets),
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

  local rate_context = get_rate_context(player, entity)

  if not rate_context then
    if player_data.selected_key then
      destroy_gui(player)
      player_data.selected_key = nil
    end

    return
  end

  local display_time_unit = get_display_time_unit(player)
  local show_belt_fill_targets = should_show_belt_fill_targets(player)
  local selected_key = get_selected_key(entity, rate_context, display_time_unit, show_belt_fill_targets)

  if player_data.selected_key == selected_key then
    return
  end

  player_data.selected_key = selected_key
  build_gui(player, entity, rate_context, display_time_unit, show_belt_fill_targets)
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
