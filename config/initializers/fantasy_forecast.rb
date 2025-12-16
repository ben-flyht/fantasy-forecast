module FantasyForecast
  # Configuration for position-based forecasting
  # The game: Beat the Bot - try to be more accurate than FantasyForecaster
  POSITION_CONFIG = {
    "goalkeeper" => {
      display_name: "GK",
      slots: 2,
      color_class: "blue"
    },
    "defender" => {
      display_name: "DEF",
      slots: 5,
      color_class: "green"
    },
    "midfielder" => {
      display_name: "MID",
      slots: 5,
      color_class: "yellow"
    },
    "forward" => {
      display_name: "FWD",
      slots: 3,
      color_class: "red"
    }
  }.freeze
end
