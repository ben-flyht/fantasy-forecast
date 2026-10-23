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

  test "a card to pick is a button the pack listens to" do
    render_inline PackCardComponent.new(card: @card, href: "/pack/1/a")

    assert_selector ".pack-card--choice[role=button][data-pack-href='/pack/1/a'][data-pack-target=choice]"
    assert_selector "[aria-label='Keep #{@card.player.display_name}']"
  end

  test "a card in the hand is not a button" do
    render_inline PackCardComponent.new(card: @card, size: :small)

    assert_no_selector "[role=button]"
    assert_selector ".pack-card--small"
  end

  test "the captain keeps his foil" do
    render_inline PackCardComponent.new(card: @card, captain: true)

    assert_selector ".pack-card--shiny .pack-card__captain", text: "C"
  end
end
