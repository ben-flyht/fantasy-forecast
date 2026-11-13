require "test_helper"

class DesignTokensTest < ActiveSupport::TestCase
  SOURCES = Dir[Rails.root.join("app/{views,components,helpers,javascript}/**/*.{erb,rb,js}")]
            .reject { |path| path.include?("/views/cards/") }

  CARD_ARTWORK = %w[player_row_component player_card_component player_compact_card_component player_hero_component].freeze

  HUES = %w[slate gray zinc neutral stone red orange amber yellow lime green emerald teal cyan sky blue indigo
            violet purple fuchsia pink rose].join("|")

  RAW_COLOUR = /(?<![\w-])(?:text|bg|border|ring|divide|decoration|outline|fill|stroke|from|via|to)-(?:#{HUES})-\d{2,3}/
  RAW_TEXT_SIZE = /(?<![\w-])text-\[\d[^\]]*\]/
  RAW_RADIUS = /(?<![\w-])rounded(?:-[a-z]{1,2})?-(?:lg|xl|2xl|3xl)\b/

  test "colours come from the palette" do
    assert_empty offences(RAW_COLOUR), "Use a colour token from Foundations > Colours"
  end

  test "text sizes come from the type scale" do
    artwork = ->(path) { CARD_ARTWORK.any? { |name| path.include?(name) } }

    assert_empty offences(RAW_TEXT_SIZE, skip: artwork), "Use a text style from Foundations > Typography"
  end

  test "corners come from the radius scale" do
    assert_empty offences(RAW_RADIUS), "Use rounded-badge, rounded-control or rounded-card"
  end

  private

  def offences(pattern, skip: ->(_path) { false })
    SOURCES.reject(&skip).flat_map do |path|
      File.read(path).scan(pattern).uniq.map { |match| "#{Pathname(path).relative_path_from(Rails.root)}: #{match}" }
    end
  end
end
