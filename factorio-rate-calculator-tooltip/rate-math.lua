local rate_math = {}

local time_units = {
  second = {
    multiplier = 1,
    suffix = "/s",
  },
  minute = {
    multiplier = 60,
    suffix = "/min",
  },
  hour = {
    multiplier = 3600,
    suffix = "/h",
  },
}

function rate_math.get_time_unit(time_unit_name)
  return time_units[time_unit_name] or time_units.minute
end

function rate_math.get_prototype_type(entry)
  return entry.type or "item"
end

function rate_math.get_prototype_name(entry)
  if rate_math.get_prototype_type(entry) == "research-progress" then
    return nil
  end

  return entry.name or entry[1]
end

function rate_math.get_ingredient_amount(ingredient)
  return ingredient.amount or ingredient[2] or 1
end

function rate_math.get_product_amount(product)
  local amount = product.amount or product[2]

  if not amount and product.amount_min and product.amount_max then
    amount = (product.amount_min + product.amount_max) / 2
  end

  return (amount or 1) * (product.probability or 1)
end

function rate_math.get_product_amount_with_productivity(product, productivity_multiplier)
  local expected_amount = rate_math.get_product_amount(product)
  local ignored_by_productivity = product.ignored_by_productivity or 0
  local productivity_base_complement = math.min(expected_amount, ignored_by_productivity)
  local productivity_base = expected_amount - productivity_base_complement

  return productivity_base_complement + productivity_base * productivity_multiplier
end

function rate_math.get_rich_text_icon(prototype_type, prototype_name)
  if prototype_type == "fluid" then
    return "[fluid=" .. prototype_name .. "]"
  end

  return "[item=" .. prototype_name .. "]"
end

function rate_math.format_number(value)
  local rounded_integer = math.floor(value + 0.5)

  if math.abs(value - rounded_integer) < 0.001 then
    return tostring(rounded_integer)
  end

  return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

function rate_math.format_rate(rate_per_second, time_unit_name)
  local time_unit = rate_math.get_time_unit(time_unit_name)

  return rate_math.format_number(rate_per_second * time_unit.multiplier) .. time_unit.suffix
end

return rate_math
