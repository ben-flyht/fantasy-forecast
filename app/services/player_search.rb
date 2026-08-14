# Finding a player from the few letters somebody has typed so far.
#
# Done in Ruby rather than in SQL, because the whole league is about seven hundred
# rows and folding accents in Postgres would mean installing an extension to search
# a table small enough to hold in a hand. "gyokeres" has to find Gyökeres: nobody is
# typing the umlaut.
#
# Ordered by ownership, which is the closest thing we have to who a manager probably
# meant. Two players called Gabriel and one of them owned by a third of the game is
# not a hard guess.
class PlayerSearch < ApplicationService
  LIMIT = 8

  # Long enough to save the roster being read on every keystroke, short enough that a
  # new signing appears the same afternoon.
  CACHE_FOR = 5.minutes

  # Excluded by the address they are found at, because that is what the caller was
  # given and what it hands back. A player already chosen is not a candidate for the
  # other half of his own comparison.
  def initialize(term:, limit: LIMIT, exclude: [])
    @term = normalise(term)
    @limit = limit
    @exclude = Array(exclude).compact_blank.map(&:to_s)
  end

  def call
    return [] if @term.blank?

    matches.sort_by { |player, rank| [ rank, -ownership_of(player), player.full_name ] }
           .first(@limit)
           .map(&:first)
  end

  private

  def matches
    roster.filter_map do |player|
      next if excluded?(player)

      rank = rank_of(player)
      [ player, rank ] if rank
    end
  end

  # His comparison address (what the builder sends), his full-name page address, or the
  # bare id an older address used. Any of them identifies him.
  def excluded?(player)
    @exclude.include?(player.comparison_param) ||
      @exclude.include?(player.to_param) ||
      @exclude.include?(player.id.to_s)
  end

  # Where in his name the typed letters land. The front of a name beats the middle
  # of one: somebody typing "hal" means Haaland before he means Mikhalchenko.
  def rank_of(player)
    best = nil
    player.searchable_names.each do |name|
      at = normalise(name).index(@term)
      next unless at

      best = [ best, at.zero? ? 0 : 1 ].compact.min
    end
    best
  end

  def ownership_of(player)
    ownership[player.id].to_f
  end

  def ownership
    @ownership ||= Rails.cache.fetch("player_search/ownership", expires_in: CACHE_FOR) do
      Statistic.where(type: "selected_by_percent").latest_by_player
               .transform_values { |reading| reading["selected_by_percent"] }
    end
  end

  def roster
    @roster ||= Player.includes(:team).to_a
  end

  # Case and accents folded away, so what he is spelled with does not have to be
  # what the reader spells him with.
  def normalise(value)
    value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
  end
end
