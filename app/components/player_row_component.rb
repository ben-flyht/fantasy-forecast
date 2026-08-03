# frozen_string_literal: true

class PlayerRowComponent < ViewComponent::Base
  def initialize(ranking:, player:, facts:, show_position: false, hero: false)
    @ranking = ranking
    @player = player
    @facts = facts || {}
    @show_position = show_position
    @hero = hero
  end

  private

  attr_reader :ranking, :player, :facts

  def hero?
    @hero
  end

  def card_height = hero? ? "h-64" : "h-24"
  def side_width = hero? ? "w-24" : "w-[54px]"
  def corner_text = hero? ? "text-5xl" : "text-[32px]"
  def name_text = hero? ? "text-3xl" : "text-[21px]"
  def given_text = hero? ? "text-xs" : "text-[10px]"
  def meta_text = hero? ? "text-base" : "text-[10.5px]"
  def badge_size = hero? ? "h-[220px] w-[220px]" : "h-[120px] w-[120px]"
  def cutout_height = hero? ? "h-[248px]" : "h-[100px]"
  def banner_pad = hero? ? "pl-9" : "pl-6"

  def position_label
    return unless @show_position

    player.position&.capitalize
  end

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
