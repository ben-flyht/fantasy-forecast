# frozen_string_literal: true

class PlayerRowComponent < ViewComponent::Base
  def initialize(ranking:, player:, facts:)
    @ranking = ranking
    @player = player
    @facts = facts || {}
  end

  private

  attr_reader :ranking, :player, :facts

  def rank
    ranking.bot_rank || "-"
  end

  def grade
    ranking.grade
  end

  def team
    player.team
  end

  def color
    team&.color || Team::DEFAULT_COLOR
  end

  def text_class
    team&.on_light? ? "text-zinc-900" : "text-white"
  end

  def cost
    helpers.player_price(facts["now_cost"])
  end

  def ownership
    value = facts["selected_by_percent"]
    return nil if value.blank?

    format("%.1f%%", value.to_f)
  end

  def transfer_movement
    net = facts["transfers_in"].to_i - facts["transfers_out"].to_i
    return nil if net.zero?

    "#{net.positive? ? '▲' : '▼'}#{abbreviate(net.abs)}"
  end

  def abbreviate(number)
    number >= 1_000 ? "#{(number / 1_000.0).round}k" : number.to_s
  end
end
