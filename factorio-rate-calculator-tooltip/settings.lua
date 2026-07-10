local time_unit_values = { "second", "minute", "hour" }

data:extend({
  {
    type = "string-setting",
    name = "factorio-rate-calculator-tooltip-recipe-tooltip-time-unit",
    setting_type = "startup",
    default_value = "minute",
    allowed_values = time_unit_values,
    order = "a[recipe-tooltip]-a[time-unit]",
  },
  {
    type = "string-setting",
    name = "factorio-rate-calculator-tooltip-live-tooltip-time-unit",
    setting_type = "runtime-per-user",
    default_value = "minute",
    allowed_values = time_unit_values,
    order = "b[live-tooltip]-a[time-unit]",
  },
})
