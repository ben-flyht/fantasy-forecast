class PackArchive < ApplicationService
  def call
    Gameweek.where(id: Selection.where(archive: nil).select(:gameweek_id)).find_each.sum { |gameweek| archive(gameweek) }
  end

  private

  def archive(gameweek)
    board = PackLeaderboard.new(gameweek)
    board.rows.each { |row| row.selection.update_columns(archive: record(gameweek, row, board.real)) }
    board.rows.size
  end

  def record(gameweek, row, real)
    hand = row.selection.pack_hand
    { "gameweek" => gameweek.fpl_id, "place" => row.place, "points" => row.points,
      "got" => row.got, "possible" => row.possible, "pairs" => row.pairs,
      "hand" => hand.pack.pairs.each_with_index.map { |pair, index| pair_record(pair, hand.choice_at(index), real) } }
  end

  def pair_record(pair, kept, real)
    { "shiny" => pair.shiny?, "kept" => kept,
      "cards" => pair.cards.map { |card| card_record(card, real) } }
  end

  def card_record(card, real)
    { "player" => card.player.display_name, "team" => card.player.team&.short_name,
      "position" => card.position, "points" => real.of(card) }
  end
end
