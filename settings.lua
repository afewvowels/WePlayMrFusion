data:extend({
  {
    type = "int-setting",
    name = "wp-mr-fusion-items-per-second",
    setting_type = "runtime-global",
    default_value = 2,
    minimum_value = 1,
    maximum_value = 100,
    order = "a"
  },
  {
    type = "double-setting",
    name = "wp-mr-fusion-fuel-efficiency",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0,
    maximum_value = 10,
    order = "b"
  },
  {
    type = "double-setting",
    name = "wp-mr-fusion-junk-energy",
    setting_type = "runtime-global",
    default_value = 200, -- kJ per non-fuel item
    minimum_value = 0,
    maximum_value = 1000000,
    order = "c"
  }
})
