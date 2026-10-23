class WeeklyPack < ApplicationRecord
  belongs_to :gameweek
  has_many :pack_entries, dependent: :destroy

  def self.for(gameweek)
    find_by(gameweek: gameweek) || draw(gameweek)
  end

  def self.open?(gameweek)
    previous = Gameweek.find_by(fpl_id: gameweek.fpl_id - 1)
    gameweek.start_time.future? && (previous.nil? || previous.is_finished)
  end

  def self.draw(gameweek)
    return unless open?(gameweek)

    pack = PackDraw.call(gameweek: gameweek, seed: gameweek.fpl_id)
    create!(gameweek: gameweek, seed: pack.seed, pairs: pack.pairs.map { |pair| row(pair) }) if pack
  rescue ActiveRecord::RecordNotUnique
    find_by(gameweek: gameweek)
  end

  def self.row(pair)
    { "slot" => pair.slot, "shiny" => pair.shiny?,
      "cards" => pair.cards.map { |card| { "player_id" => card.player_id, "rank" => card.rank,
                                           "expected_points" => card.expected_points, "fixtures" => card.fixtures } } }
  end

  def pack
    @pack ||= Pack.new(seed: seed, pairs: pairs.map { |row| pair(row) })
  end

  def locked? = gameweek.start_time.past?

  def entry_for(manager)
    pack_entries.find_by(manager: manager) if manager
  end

  private

  def pair(row)
    cards = row["cards"].map do |card|
      Pack::Card.new(player: players.fetch(card["player_id"]), rank: card["rank"],
                     expected_points: card["expected_points"], fixtures: card["fixtures"])
    end
    Pack::Pair.new(slot: row["slot"], cards: cards, shiny: row["shiny"])
  end

  def players
    @players ||= Player.includes(:team)
                       .where(id: pairs.flat_map { |row| row["cards"].map { |card| card["player_id"] } })
                       .index_by(&:id)
  end
end
