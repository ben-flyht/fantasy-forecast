class WeeklyPack < ApplicationRecord
  SEEDS = 1..999_999_999

  belongs_to :gameweek
  has_many :pack_entries, dependent: :destroy

  def self.for(gameweek)
    find_by(gameweek: gameweek) || draw(gameweek)
  end

  def self.draw(gameweek)
    return if gameweek.start_time.past?

    seed = Random.new(gameweek.fpl_id).rand(SEEDS)
    pack = PackDraw.call(gameweek: gameweek, seed: seed)
    return unless pack

    create!(gameweek: gameweek, seed: seed, pairs: pack.pairs.map { |pair| pair_row(pair) })
  rescue ActiveRecord::RecordNotUnique
    find_by(gameweek: gameweek)
  end

  def self.pair_row(pair)
    { "slot" => pair.slot, "shiny" => pair.shiny?,
      "cards" => pair.cards.map { |card| card.to_h.except(:player).merge(player_id: card.player_id).stringify_keys } }
  end

  def pack
    @pack ||= Pack.new(seed: seed, pairs: pairs.map { |row| rebuild_pair(row) })
  end

  def locked? = gameweek.start_time.past?

  def entry_for(manager)
    pack_entries.find_by(manager: manager) if manager
  end

  private

  def rebuild_pair(row)
    cards = row["cards"].map do |card|
      PickablePool::Candidate.new(player: players.fetch(card["player_id"]), rank: card["rank"],
                                  cost: card["cost"], expected_points: card["expected_points"])
    end
    Pack::Pair.new(slot: row["slot"], cards: cards, shiny: row["shiny"])
  end

  def players
    @players ||= Player.includes(:team)
                       .where(id: pairs.flat_map { |row| row["cards"].map { |card| card["player_id"] } })
                       .index_by(&:id)
  end
end
