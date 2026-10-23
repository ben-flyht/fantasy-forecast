class PackDraw < ApplicationService
  GRADED = TierCalculator::POINT_THRESHOLDS[:t4]
  STARTING_MINUTES = 60
  CAPTAINCY = %w[midfielder forward].freeze
  SEEDS = 1..999_999_999

  def initialize(gameweek:, seed: rand(SEEDS))
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
    Pack.new(pairs: pairs)
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
                         .where("(working->>'minutes')::float >= ?", STARTING_MINUTES)
                         .includes(player: :team)
                         .map { |forecast| card(forecast) }
                         .group_by(&:position)
                         .transform_values { |cards| cards.sort_by { |card| [ -card.expected_points, card.rank || Float::INFINITY, card.player_id ] } }
  end

  def card(forecast)
    Pack::Card.new(player: forecast.player, rank: forecast.rank, expected_points: forecast.score.to_f,
                   fixtures: fixtures_for(forecast.player.team_id))
  end

  def fixtures_for(team_id)
    matches.fetch(team_id, []).map do |match|
      "#{match.opponent_for(team_id)&.short_name} (#{match.home_for?(team_id) ? 'H' : 'A'})"
    end
  end

  def matches
    @matches ||= Match.by_team(gameweek)
  end
end
