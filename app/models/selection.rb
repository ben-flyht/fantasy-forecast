class Selection < ApplicationRecord
  SEEDS = 1..999_999_999

  belongs_to :user
  belongs_to :gameweek

  validates :user_id, uniqueness: { scope: :gameweek_id }
  validates :picks, format: { with: /\A[abx]*\z/ }
  validate :within_the_pack
  validate :before_the_deadline, if: :picks_changed?

  def self.open?(gameweek)
    previous = Gameweek.find_by(fpl_id: gameweek.fpl_id - 1)
    gameweek.start_time.future? && (previous.nil? || previous.is_finished)
  end

  def self.deal(user, gameweek)
    find_by(user: user, gameweek: gameweek) || (draw(user, gameweek) if open?(gameweek))
  end

  def self.draw(user, gameweek)
    pack = PackDraw.call(gameweek: gameweek, seed: rand(SEEDS))
    create!(user: user, gameweek: gameweek, offered: pack.pairs.map { |pair| row(pair) }) if pack
  rescue ActiveRecord::RecordNotUnique
    find_by(user: user, gameweek: gameweek)
  end

  def self.row(pair)
    { "slot" => pair.slot, "shiny" => pair.shiny?,
      "cards" => pair.cards.map { |card| { "player_id" => card.player_id, "rank" => card.rank,
                                           "expected_points" => card.expected_points, "fixtures" => card.fixtures } } }
  end

  def pack
    @pack ||= Pack.new(seed: nil, pairs: offered.map { |row| pair(row) })
  end

  def locked? = gameweek.start_time.past?

  def pack_hand
    code = locked? ? picks.ljust(pack.size, PackHand::FORFEIT) : picks
    PackHand.parse(pack, code)
  end

  def complete? = pack_hand&.complete?

  def pick(choice)
    return false if complete? || !PackHand::FORMAT.match?(choice.to_s) || choice.to_s.size != 1

    self.picks = picks + choice
    save
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
                       .where(id: offered.flat_map { |row| row["cards"].map { |card| card["player_id"] } })
                       .index_by(&:id)
  end

  def within_the_pack
    errors.add(:picks, "is longer than the pack") if picks.to_s.size > offered.size
  end

  def before_the_deadline
    errors.add(:base, "The deadline has passed.") if gameweek&.start_time&.past?
  end
end
