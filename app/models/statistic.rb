class Statistic < ApplicationRecord
  # Disable Single Table Inheritance since we're using 'type' for stat type
  self.inheritance_column = :_type_disabled

  belongs_to :player
  belongs_to :gameweek

  validates :type, presence: true
  validates :value, presence: true, numericality: true
  validates :player_id, uniqueness: { scope: [ :gameweek_id, :type ] }

  # Scopes for common queries
  scope :for_gameweek, ->(gameweek) { where(gameweek: gameweek) }
  scope :for_player, ->(player) { where(player: player) }
  scope :of_type, ->(type) { where(type: type) }

  # Stores readings, and returns how many of them were news.
  #
  # FPL republishes the same figures hour after hour: between one deadline and the
  # next, almost nothing a player has done changes. An upsert of an unchanged
  # reading still writes a new version of the row in every index it appears in, so
  # a season of hourly runs buried a couple of megabytes of readings under eighty
  # of index. Asking what we already hold costs one read of the same rows and
  # saves writing nearly all of them.
  def self.store(rows)
    moved = changed_among(rows)
    upsert_all(moved, unique_by: %i[player_id gameweek_id type]) if moved.any?
    moved.size
  end

  # Compared at the precision the column keeps. A rate rounded to two places on
  # the way in would otherwise never match the one we rounded last hour, and every
  # row would look like news.
  def self.changed_among(rows)
    return rows if rows.empty?

    held = held_among(rows)
    rows.reject { |row| held[key_for(row)] == row[:value].to_f.round(2) }
  end

  def self.held_among(rows)
    where(player_id: rows.pluck(:player_id).uniq, gameweek_id: rows.pluck(:gameweek_id).uniq,
          type: rows.pluck(:type).uniq)
      .pluck(:player_id, :gameweek_id, :type, :value)
      .to_h { |player_id, gameweek_id, type, value| [ [ player_id, gameweek_id, type ], value.to_f ] }
  end

  def self.key_for(row)
    [ row[:player_id], row[:gameweek_id], row[:type] ]
  end
  private_class_method :changed_among, :held_among, :key_for

  # The newest reading of each figure for each player, as
  # { player_id => { type => Float } }.
  #
  # Asked of the database rather than of Ruby. Every gameweek adds another
  # reading of the same two dozen figures, so reading the lot back to keep only
  # the last of each was ten thousand rows in August and would have been most of a
  # million by May, to answer in the same thirteen thousand either way.
  def self.latest_by_player
    newest = select("DISTINCT ON (player_id, type) player_id, type, value")
             .order(:player_id, :type, gameweek_id: :desc)

    unscoped.from(newest, :statistics)
            .pluck(:player_id, :type, :value)
            .each_with_object(Hash.new { |stats, id| stats[id] = {} }) do |(player_id, type, value), stats|
              stats[player_id][type] = value.to_f
            end
  end
end
