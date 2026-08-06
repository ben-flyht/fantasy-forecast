module FantasyForecast
  # The favicons live in public/, which Rails serves with a year of max-age and no
  # fingerprint, so Cloudflare and every browser that has seen an old one will hold it
  # until 2027. Bumping this is what makes the URL new. Change it whenever the icons do.
  ICON_VERSION = 2

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
