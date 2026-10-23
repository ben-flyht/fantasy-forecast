# frozen_string_literal: true

class PackCardComponent < ViewComponent::Base
  HIDDEN_GRADE = "?"

  def initialize(card:, href: nil, revealed: false, shiny: false, captain: false, size: :full, index: 0)
    @card = card
    @href = href
    @revealed = revealed
    @shiny = shiny
    @captain = captain
    @size = size
    @index = index
  end

  private

  attr_reader :card, :href, :index

  def player = card.player
  def team = player.team

  def classes
    [
      "pack-card",
      ("pack-card--small" if @size == :small),
      ("pack-card--shiny" if @shiny || @captain),
      ("pack-card--choice" if href)
    ].compact.join(" ")
  end

  def style
    "--club: #{team&.color || Team::DEFAULT_COLOR}; --i: #{index};"
  end

  def ink_class
    team&.on_light? ? "pack-card__face--light" : "pack-card__face--dark"
  end

  def position = helpers.position_letter(card.position)
  def price = helpers.player_price(card.cost)

  def grade
    @revealed ? TierCalculator.grade_from_points(card.expected_points) : HIDDEN_GRADE
  end

  def captain? = @captain

  def name_class
    length = player.display_name.length
    return "pack-card__name pack-card__name--longest" if length > 10
    return "pack-card__name pack-card__name--long" if length > 7

    "pack-card__name"
  end

  def tag_name = href ? :a : :div

  def data
    { controller: "pack-card",
      action: "pointermove->pack-card#tilt pointerleave->pack-card#rest pointerdown->pack-card#press " \
              "pointerup->pack-card#release pointercancel->pack-card#rest" }
  end

  def link_attributes
    return {} unless href

    { href: href, aria: { label: "Keep #{player.display_name}" } }
  end
end
