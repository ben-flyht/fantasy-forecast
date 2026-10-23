class Pack
  SLOTS = %w[goalkeeper defender midfielder forward wildcard].freeze
  OUTFIELD = %w[defender midfielder forward].freeze

  Card = Data.define(:player, :rank, :expected_points, :fixtures) do
    def initialize(player:, rank:, expected_points:, fixtures: [])
      super
    end

    def player_id = player.id
    def position = player.position
  end

  Pair = Data.define(:slot, :cards, :shiny) do
    def shiny? = shiny
    def wildcard? = slot == "wildcard"
  end

  attr_reader :pairs

  def self.load(rows)
    ids = rows.flat_map { |row| row["cards"].map { |card| card["player_id"] } }
    players = Player.includes(:team).where(id: ids).index_by(&:id)
    new(pairs: rows.map { |row| load_pair(row, players) })
  end

  def self.load_pair(row, players)
    cards = row["cards"].map do |card|
      Card.new(player: players.fetch(card["player_id"]), rank: card["rank"],
               expected_points: card["expected_points"], fixtures: card["fixtures"])
    end
    Pair.new(slot: row["slot"], cards: cards, shiny: row["shiny"])
  end

  def initialize(pairs:)
    @pairs = pairs
  end

  def dump
    pairs.map do |pair|
      { "slot" => pair.slot, "shiny" => pair.shiny?,
        "cards" => pair.cards.map { |card| card.to_h.except(:player).merge(player_id: card.player_id).stringify_keys } }
    end
  end

  def size = pairs.size

  def shiny_index = pairs.index(&:shiny?)
end
