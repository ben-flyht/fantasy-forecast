require "test_helper"

class PackCardComponentTest < ViewComponent::TestCase
  setup do
    team = Team.new(name: "Card City", short_name: "CRD")
    player = Player.new(id: 1, first_name: "Test", last_name: "Winger", short_name: "Winger", position: "midfielder", team: team)
    @card = Pack::Card.new(player: player, rank: 4, cost: 65, expected_points: 4.6)
  end

  test "the grade stays face down until the pack is scored" do
    render_inline PackCardComponent.new(card: @card)
    assert_selector "[data-pack-grade]", text: "?"

    render_inline PackCardComponent.new(card: @card, revealed: true)
    assert_selector "[data-pack-grade]", text: "A"
  end

  test "a card to pick is a link to the hand that keeps it" do
    render_inline PackCardComponent.new(card: @card, href: "/pack/1/a")

    assert_selector "a.pack-card--choice[href='/pack/1/a'][aria-label='Keep #{@card.player.display_name}']"
  end

  test "a card in the hand is not a link" do
    render_inline PackCardComponent.new(card: @card, size: :small)

    assert_no_selector "a"
    assert_selector ".pack-card--small"
  end

  test "the captain keeps his foil" do
    render_inline PackCardComponent.new(card: @card, captain: true)

    assert_selector ".pack-card--shiny .pack-card__captain", text: "C"
  end

  test "a card says who he plays, and where" do
    render_inline PackCardComponent.new(card: @card.with(fixtures: [ "ARS (H)" ]))
    assert_selector "[data-pack-fixture]", text: "v ARS (H)"

    render_inline PackCardComponent.new(card: @card)
    assert_selector "[data-pack-fixture]", text: "no game"
  end

  test "a shiny card carries the coloured flecks" do
    render_inline PackCardComponent.new(card: @card, shiny: true)

    assert_selector ".pack-card--shiny .pack-card__glitter--flecks-a"
  end
end
