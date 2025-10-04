module FantasyForecast
  # Configuration for position-based forecasting
  POSITION_CONFIG = {
    "goalkeeper" => {
      display_name: "GK",
      slots: 5,
      color_class: "blue"
    },
    "defender" => {
      display_name: "DEF",
      slots: 10,
      color_class: "green"
    },
    "midfielder" => {
      display_name: "MID",
      slots: 10,
      color_class: "yellow"
    },
    "forward" => {
      display_name: "FWD",
      slots: 5,
      color_class: "red"
    }
  }.freeze
end
