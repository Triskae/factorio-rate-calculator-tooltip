local rate_math = require("rate-math")

local crafting_machine_prototype_types = {
  "assembling-machine",
  "furnace",
  "rocket-silo",
}

local recipe_tooltip_time_unit_setting_name = "factorio-rate-calculator-tooltip-recipe-tooltip-time-unit"
local tooltip_order_start = 220
local display_time_unit = settings.startup[recipe_tooltip_time_unit_setting_name].value
local max_tooltip_value_length = 180
local max_rate_entries_per_field = 8
local rate_text_separator = "  "

local function get_recipe_ingredients(recipe)
  return recipe.ingredients or {}
end

local function get_recipe_products(recipe)
  if recipe.results then
    return recipe.results
  end

  if recipe.result then
    return {
      {
        type = "item",
        name = recipe.result,
        amount = recipe.result_count or 1,
      },
    }
  end

  return {}
end

local function get_crafts_per_second(recipe, crafting_speed)
  return crafting_speed / (recipe.energy_required or 0.5)
end

local function append_rate_text(text, prototype_type, prototype_name, rate)
  if #text > 0 then
    text[#text + 1] = rate_text_separator
  end

  text[#text + 1] = rate_math.get_rich_text_icon(prototype_type, prototype_name)
  text[#text + 1] = " "
  text[#text + 1] = rate_math.format_rate(rate, display_time_unit)
end

local function try_append_rate_text(text, prototype_type, prototype_name, rate)
  local previous_count = #text

  append_rate_text(text, prototype_type, prototype_name, rate)

  if string.len(table.concat(text)) <= max_tooltip_value_length then
    return true
  end

  for index = #text, previous_count + 1, -1 do
    text[index] = nil
  end

  if #text > 0 then
    text[#text + 1] = rate_text_separator
  end

  text[#text + 1] = "..."

  return false
end

local function append_overflow_marker(text)
  if #text > 0 then
    text[#text + 1] = rate_text_separator
  end

  text[#text + 1] = "..."
end

local function build_ingredient_rates_text(recipe, crafts_per_second)
  local text = {}
  local displayed_entries = 0

  for _, ingredient in pairs(get_recipe_ingredients(recipe)) do
    local prototype_name = rate_math.get_prototype_name(ingredient)

    if prototype_name then
      if displayed_entries >= max_rate_entries_per_field then
        append_overflow_marker(text)
        break
      end

      local did_append = try_append_rate_text(
        text,
        rate_math.get_prototype_type(ingredient),
        prototype_name,
        rate_math.get_ingredient_amount(ingredient) * crafts_per_second
      )

      if not did_append then
        break
      end

      displayed_entries = displayed_entries + 1
    end
  end

  if #text == 0 then
    text[#text + 1] = "-"
  end

  return table.concat(text)
end

local function build_product_rates_text(recipe, crafts_per_second)
  local text = {}
  local displayed_entries = 0

  for _, product in pairs(get_recipe_products(recipe)) do
    local prototype_name = rate_math.get_prototype_name(product)

    if prototype_name then
      if displayed_entries >= max_rate_entries_per_field then
        append_overflow_marker(text)
        break
      end

      local did_append = try_append_rate_text(
        text,
        rate_math.get_prototype_type(product),
        prototype_name,
        rate_math.get_product_amount(product) * crafts_per_second
      )

      if not did_append then
        break
      end

      displayed_entries = displayed_entries + 1
    end
  end

  if #text == 0 then
    text[#text + 1] = "-"
  end

  return table.concat(text)
end

local function get_category_set(machine)
  local category_set = {}

  for key, value in pairs(machine.crafting_categories or {}) do
    if value == true then
      category_set[key] = true
    else
      category_set[value] = true
    end
  end

  return category_set
end

local function recipe_matches_crafting_machine(recipe, crafting_machine)
  if recipe.categories then
    for _, recipe_category in pairs(recipe.categories) do
      if crafting_machine.category_set[recipe_category] == true then
        return true
      end
    end

    return false
  end

  return crafting_machine.category_set[recipe.category or "crafting"] == true
end

local function has_crafting_categories(machine)
  for _, _ in pairs(machine.crafting_categories or {}) do
    return true
  end

  return false
end

local function get_crafting_machine_sort_key(machine_name, machine)
  return table.concat({
    tostring(machine.order or ""),
    tostring(machine.group or ""),
    tostring(machine.subgroup or ""),
    machine_name,
  }, "|")
end

local function build_crafting_machine_data()
  local crafting_machines = {}

  for _, prototype_type in ipairs(crafting_machine_prototype_types) do
    for machine_name, machine in pairs(data.raw[prototype_type] or {}) do
      if not machine.hidden and has_crafting_categories(machine) then
        crafting_machines[#crafting_machines + 1] = {
          category_set = get_category_set(machine),
          crafting_speed = machine.crafting_speed or 1,
          icon = "[entity=" .. machine_name .. "]",
          name = machine_name,
          sort_key = get_crafting_machine_sort_key(machine_name, machine),
        }
      end
    end
  end

  table.sort(crafting_machines, function(left, right)
    return left.sort_key < right.sort_key
  end)

  return crafting_machines
end

local function get_recipe_crafting_machines(recipe, crafting_machine_data)
  local recipe_crafting_machines = {}

  for _, crafting_machine in ipairs(crafting_machine_data) do
    if recipe_matches_crafting_machine(recipe, crafting_machine) then
      recipe_crafting_machines[#recipe_crafting_machines + 1] = crafting_machine
    end
  end

  return recipe_crafting_machines
end

local function has_compatible_crafting_machine(recipe_crafting_machines)
  return #recipe_crafting_machines > 0
end

local function recipe_has_item_product(recipe)
  for _, product in pairs(get_recipe_products(recipe)) do
    if rate_math.get_prototype_name(product) then
      return true
    end
  end

  return false
end

local function add_recipe_separator(recipe, order)
  table.insert(recipe.custom_tooltip_fields, {
    name = { "", "" },
    value = { "", "[color=128,128,128]────────────────[/color]" },
    order = order,
    show_in_tooltip = true,
    show_in_factoriopedia = true,
  })
end

local function add_recipe_crafting_machine_tooltips(recipe, recipe_crafting_machines)
  if not has_compatible_crafting_machine(recipe_crafting_machines) then
    return
  end

  if not recipe_has_item_product(recipe) then
    return
  end

  recipe.custom_tooltip_fields = recipe.custom_tooltip_fields or {}
  add_recipe_separator(recipe, tooltip_order_start)

  for index, crafting_machine in ipairs(recipe_crafting_machines) do
    local crafts_per_second = get_crafts_per_second(recipe, crafting_machine.crafting_speed)
    local order = tooltip_order_start + (index * 3)

    if index > 1 then
      add_recipe_separator(recipe, order)
    end

    table.insert(recipe.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-input-label", crafting_machine.icon },
      value = build_ingredient_rates_text(recipe, crafts_per_second),
      order = order + 1,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })

    table.insert(recipe.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-output-label", crafting_machine.icon },
      value = build_product_rates_text(recipe, crafts_per_second),
      order = order + 2,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })
  end
end

local crafting_machine_data = build_crafting_machine_data()

for _, recipe in pairs(data.raw.recipe or {}) do
  add_recipe_crafting_machine_tooltips(recipe, get_recipe_crafting_machines(recipe, crafting_machine_data))
end
