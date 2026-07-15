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

local function build_ingredient_rates_text(ingredients, operations_per_second)
  local text = {}
  local displayed_entries = 0

  for _, ingredient in pairs(ingredients or {}) do
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
        rate_math.get_ingredient_amount(ingredient) * operations_per_second
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

local function build_product_rates_text(products, operations_per_second)
  local text = {}
  local displayed_entries = 0

  for _, product in pairs(products or {}) do
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
        rate_math.get_product_amount(product) * operations_per_second
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

local function get_minable_ingredients(minable)
  if minable.required_fluid and minable.fluid_amount then
    return {
      {
        type = "fluid",
        name = minable.required_fluid,
        amount = minable.fluid_amount,
      },
    }
  end

  return {}
end

local function get_minable_products(minable)
  if minable.results then
    return minable.results
  end

  if minable.result then
    return {
      {
        type = "item",
        name = minable.result,
        amount = minable.count or 1,
      },
    }
  end

  return {}
end

local function get_mining_operations_per_second(resource, mining_speed)
  return mining_speed / ((resource.minable and resource.minable.mining_time) or 1)
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

local function get_resource_category_set(mining_drill)
  local category_set = {}

  for key, value in pairs(mining_drill.resource_categories or {}) do
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

local function has_resource_categories(mining_drill)
  for _, _ in pairs(mining_drill.resource_categories or {}) do
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

local function build_mining_drill_data()
  local mining_drills = {}

  for mining_drill_name, mining_drill in pairs(data.raw["mining-drill"] or {}) do
    if not mining_drill.hidden and has_resource_categories(mining_drill) then
      mining_drills[#mining_drills + 1] = {
        category_set = get_resource_category_set(mining_drill),
        icon = "[entity=" .. mining_drill_name .. "]",
        mining_speed = mining_drill.mining_speed or 1,
        name = mining_drill_name,
        prototype = mining_drill,
        sort_key = get_crafting_machine_sort_key(mining_drill_name, mining_drill),
      }
    end
  end

  table.sort(mining_drills, function(left, right)
    return left.sort_key < right.sort_key
  end)

  return mining_drills
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

local function resource_matches_mining_drill(resource, mining_drill)
  return mining_drill.category_set[resource.category or "basic-solid"] == true
end

local function get_resource_mining_drills(resource, mining_drill_data)
  local resource_mining_drills = {}

  for _, mining_drill in ipairs(mining_drill_data) do
    if resource_matches_mining_drill(resource, mining_drill) then
      resource_mining_drills[#resource_mining_drills + 1] = mining_drill
    end
  end

  return resource_mining_drills
end

local function get_mining_drill_resources(mining_drill, resource_data)
  local mining_drill_resources = {}

  for _, resource in ipairs(resource_data) do
    if resource_matches_mining_drill(resource.prototype, mining_drill) then
      mining_drill_resources[#mining_drill_resources + 1] = resource
    end
  end

  return mining_drill_resources
end

local function build_resource_data()
  local resources = {}

  for resource_name, resource in pairs(data.raw.resource or {}) do
    if resource.minable and #get_minable_products(resource.minable) > 0 then
      resources[#resources + 1] = {
        icon = "[entity=" .. resource_name .. "]",
        name = resource_name,
        prototype = resource,
        sort_key = get_crafting_machine_sort_key(resource_name, resource),
      }
    end
  end

  table.sort(resources, function(left, right)
    return left.sort_key < right.sort_key
  end)

  return resources
end

local function has_compatible_crafting_machine(recipe_crafting_machines)
  return #recipe_crafting_machines > 0
end

local function has_compatible_mining_drill(resource_mining_drills)
  return #resource_mining_drills > 0
end

local function recipe_has_item_product(recipe)
  for _, product in pairs(get_recipe_products(recipe)) do
    if rate_math.get_prototype_name(product) then
      return true
    end
  end

  return false
end

local function resource_has_item_product(resource)
  for _, product in pairs(get_minable_products(resource.minable or {})) do
    if rate_math.get_prototype_name(product) then
      return true
    end
  end

  return false
end

local function add_tooltip_separator(prototype, order)
  table.insert(prototype.custom_tooltip_fields, {
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
  add_tooltip_separator(recipe, tooltip_order_start)

  for index, crafting_machine in ipairs(recipe_crafting_machines) do
    local crafts_per_second = get_crafts_per_second(recipe, crafting_machine.crafting_speed)
    local order = tooltip_order_start + (index * 3)

    if index > 1 then
      add_tooltip_separator(recipe, order)
    end

    table.insert(recipe.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-input-label", crafting_machine.icon },
      value = build_ingredient_rates_text(get_recipe_ingredients(recipe), crafts_per_second),
      order = order + 1,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })

    table.insert(recipe.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-output-label", crafting_machine.icon },
      value = build_product_rates_text(get_recipe_products(recipe), crafts_per_second),
      order = order + 2,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })
  end
end

local function add_resource_mining_drill_tooltips(resource, resource_mining_drills)
  if not has_compatible_mining_drill(resource_mining_drills) then
    return
  end

  if not resource_has_item_product(resource) then
    return
  end

  resource.custom_tooltip_fields = resource.custom_tooltip_fields or {}
  add_tooltip_separator(resource, tooltip_order_start)

  for index, mining_drill in ipairs(resource_mining_drills) do
    local operations_per_second = get_mining_operations_per_second(resource, mining_drill.mining_speed)
    local order = tooltip_order_start + (index * 3)

    if index > 1 then
      add_tooltip_separator(resource, order)
    end

    table.insert(resource.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-input-label", mining_drill.icon },
      value = build_ingredient_rates_text(get_minable_ingredients(resource.minable), operations_per_second),
      order = order + 1,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })

    table.insert(resource.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-output-label", mining_drill.icon },
      value = build_product_rates_text(get_minable_products(resource.minable), operations_per_second),
      order = order + 2,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })
  end
end

local function add_mining_drill_resource_tooltips(prototype, mining_drill, mining_drill_resources)
  if #mining_drill_resources == 0 then
    return
  end

  prototype.custom_tooltip_fields = prototype.custom_tooltip_fields or {}
  add_tooltip_separator(prototype, tooltip_order_start)

  for index, resource in ipairs(mining_drill_resources) do
    local operations_per_second = get_mining_operations_per_second(resource.prototype, mining_drill.mining_speed)
    local order = tooltip_order_start + (index * 3)

    if index > 1 then
      add_tooltip_separator(prototype, order)
    end

    table.insert(prototype.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-input-label", resource.icon },
      value = build_ingredient_rates_text(get_minable_ingredients(resource.prototype.minable), operations_per_second),
      order = order + 1,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })

    table.insert(prototype.custom_tooltip_fields, {
      name = { "factorio-rate-calculator-tooltip.crafting-machine-output-label", resource.icon },
      value = build_product_rates_text(get_minable_products(resource.prototype.minable), operations_per_second),
      order = order + 2,
      show_in_tooltip = true,
      show_in_factoriopedia = true,
    })
  end
end

local function add_mining_drill_item_tooltips(mining_drill, mining_drill_resources)
  for _, item in pairs(data.raw.item or {}) do
    if item.place_result == mining_drill.name then
      add_mining_drill_resource_tooltips(item, mining_drill, mining_drill_resources)
    end
  end
end

local crafting_machine_data = build_crafting_machine_data()
local mining_drill_data = build_mining_drill_data()
local resource_data = build_resource_data()

for _, recipe in pairs(data.raw.recipe or {}) do
  add_recipe_crafting_machine_tooltips(recipe, get_recipe_crafting_machines(recipe, crafting_machine_data))
end

for _, resource in ipairs(resource_data) do
  add_resource_mining_drill_tooltips(resource.prototype, get_resource_mining_drills(resource.prototype, mining_drill_data))
end

for _, mining_drill in ipairs(mining_drill_data) do
  local mining_drill_resources = get_mining_drill_resources(mining_drill, resource_data)

  add_mining_drill_resource_tooltips(mining_drill.prototype, mining_drill, mining_drill_resources)
  add_mining_drill_item_tooltips(mining_drill, mining_drill_resources)
end
