class PackDraw < ApplicationService
  GRADED = TierCalculator::POINT_THRESHOLDS[:t4]
  CAPTAINCY = %w[midfielder forward].freeze

  def initialize(gameweek:, seed:)
    @gameweek = gameweek
    @seed = seed
  end

  def call
    return if gameweek.nil?

    random = Random.new(seed)
    drawn = Set.new
    cards = Pack::SLOTS.map { |slot| draw(slot, random, drawn) }
    return if cards.any?(&:nil?)

    assemble(cards, shiny_index(cards, random))
  end

  private

  attr_reader :gameweek, :seed

  def shiny_index(cards, random)
    cards.each_index.select { |index| CAPTAINCY.include?(cards[index].first.position) }.sample(random: random)
  end

  def assemble(cards, shiny)
    pairs = Pack::SLOTS.each_with_index.map do |slot, index|
      Pack::Pair.new(slot: slot, cards: cards[index], shiny: index == shiny)
    end
    Pack.new(seed: seed, pairs: pairs)
  end

  def draw(slot, random, drawn)
    positions_for(slot, random).each do |position|
      pair = neighbours(position, random, drawn)
      next if pair.nil?

      drawn.merge(pair.map(&:player_id))
      return pair.shuffle(random: random)
    end
    nil
  end

  def positions_for(slot, random)
    slot == "wildcard" ? Pack::OUTFIELD.shuffle(random: random) : [ slot ]
  end

  def neighbours(position, random, drawn)
    ladder = ladders.fetch(position, [])
    starts = (0...ladder.size - 1).reject { |index| ladder[index, 2].any? { |card| drawn.include?(card.player_id) } }
    return if starts.empty?

    ladder[starts.sample(random: random), 2]
  end

  def ladders
    @ladders ||= Forecast.where(gameweek: gameweek, horizon: "gameweek").where(score: GRADED..)
                         .includes(player: :team)
                         .map { |forecast| card(forecast) }
                         .group_by(&:position)
                         .transform_values { |cards| cards.sort_by { |card| [ -card.expected_points, card.rank || Float::INFINITY, card.player_id ] } }
  end

  def card(forecast)
    Pack::Card.new(player: forecast.player, rank: forecast.rank, cost: costs.dig(forecast.player_id, "now_cost"),
                   expected_points: forecast.score.to_f)
  end

  def costs
    @costs ||= Statistic.where(type: "now_cost").latest_by_player
  end
end
