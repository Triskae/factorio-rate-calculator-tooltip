local rate_math = require("rate-math")

local assembler_prototypes = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
}

local tooltip_order_start = 220
local display_time_unit = "minute"
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

local function get_category_set(assembler)
  local category_set = {}

  for key, value in pairs(assembler.crafting_categories or {}) do
    if value == true then
      category_set[key] = true
    else
      category_set[value] = true
    end
  end

  return category_set
end

local function recipe_matches_assembler(recipe, assembler_data)
  if recipe.categories then
    for _, recipe_category in pairs(recipe.categories) do
      if assembler_data.category_set[recipe_category] == true then
        return true
      end
    end

    return false
  end

  return assembler_data.category_set[recipe.category or "crafting"] == true
end

local function build_assembler_data()
  local assemblers = {}

  for _, assembler_name in ipairs(assembler_prototypes) do
    local assembler = data.raw["assembling-machine"][assembler_name]

    if assembler then
      assemblers[assembler_name] = {
        category_set = get_category_set(assembler),
        crafting_speed = assembler.crafting_speed or 1,
      }
    end
  end

  return assemblers
end

local function get_recipe_assemblers(recipe, assembler_data)
  local recipe_assemblers = {}

  for _, assembler_name in ipairs(assembler_prototypes) do
    if assembler_data[assembler_name] and recipe_matches_assembler(recipe, assembler_data[assembler_name]) then
      recipe_assemblers[assembler_name] = true
    end
  end

  return recipe_assemblers
end

local function has_compatible_assembler(recipe_assemblers)
  for _, assembler_name in ipairs(assembler_prototypes) do
    if recipe_assemblers[assembler_name] then
      return true
    end
  end

  return false
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

local function add_recipe_assembler_tooltips(recipe, recipe_assemblers, assembler_data)
  if not has_compatible_assembler(recipe_assemblers) then
    return
  end

  if not recipe_has_item_product(recipe) then
    return
  end

  recipe.custom_tooltip_fields = recipe.custom_tooltip_fields or {}
  add_recipe_separator(recipe, tooltip_order_start)

  for index, assembler_name in ipairs(assembler_prototypes) do
    if recipe_assemblers[assembler_name] then
      local crafts_per_second = get_crafts_per_second(recipe, assembler_data[assembler_name].crafting_speed)
      local order = tooltip_order_start + (index * 3)

      if index > 1 then
        add_recipe_separator(recipe, order)
      end

      table.insert(recipe.custom_tooltip_fields, {
        name = { "", "[item=" .. assembler_name .. "] Entrées" },
        value = build_ingredient_rates_text(recipe, crafts_per_second),
        order = order + 1,
        show_in_tooltip = true,
        show_in_factoriopedia = true,
      })

      table.insert(recipe.custom_tooltip_fields, {
        name = { "", "[item=" .. assembler_name .. "] Sorties" },
        value = build_product_rates_text(recipe, crafts_per_second),
        order = order + 2,
        show_in_tooltip = true,
        show_in_factoriopedia = true,
      })
    end
  end
end

local assembler_data = build_assembler_data()

for _, recipe in pairs(data.raw.recipe or {}) do
  add_recipe_assembler_tooltips(recipe, get_recipe_assemblers(recipe, assembler_data), assembler_data)
end
