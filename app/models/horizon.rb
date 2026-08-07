# How far ahead a forecast is read.
#
# There were two of these and they were asked about as a yes or no: everything on the
# site wanted to know whether it was looking at the season, and answered every other
# question from that. A third distance makes that shape wrong, because "not the
# season" stops meaning "this week".
#
# So a horizon is a thing rather than a flag. It knows the run of gameweeks it spans,
# which is the only question the forecaster, the grader and the pages all actually
# ask, in three different accents:
#
#   the forecaster  which fixtures am I reading?
#   the grader      how many weeks is this score spread over?
#   the pages       what do I call it, and what does it cost to say?
class Horizon
  # How far the middle horizon looks. Every label is written from this number rather
  # than repeating it, so moving to four or six weeks renames nothing and redirects
  # nothing: the stored key and the address do not carry it.
  WINDOW = 5

  GAMEWEEK = "gameweek".freeze
  UPCOMING = "upcoming".freeze
  SEASON = "season".freeze

  KEYS = [ GAMEWEEK, UPCOMING, SEASON ].freeze

  attr_reader :key

  def self.all = KEYS.map { |key| new(key) }

  # Anything unrecognised is the coming week. A horizon arrives from a URL, and a
  # stranger's guess at one should be answered rather than refused.
  def self.find(key) = new(KEYS.include?(key.to_s) ? key.to_s : GAMEWEEK)

  def self.default = new(GAMEWEEK)

  def initialize(key)
    @key = key
  end

  def gameweek? = key == GAMEWEEK
  def upcoming? = key == UPCOMING
  def season? = key == SEASON

  # The run of gameweeks this reads over, always starting at the next one.
  def gameweeks
    case key
    when GAMEWEEK then Gameweek.remaining.limit(1)
    when UPCOMING then Gameweek.remaining.limit(WINDOW)
    else Gameweek.remaining
    end
  end

  # What a score over this horizon is divided by to read as a single week, so a grade
  # means the same thing whichever distance it was worked out over.
  #
  # Counted rather than assumed: near the end of a season "the next five" is however
  # many are left, and a horizon with no football in it still has to be safe to
  # divide by.
  def divisor = [ gameweeks.count, 1 ].max

  # What it is called, and what it is called when there is no room for that.
  #
  # Written from WINDOW rather than repeating the number, so the label cannot come to
  # disagree with the football it covers. Three options do not fit a phone at full
  # length, which is what the short one is for: the control shows it below sm and
  # keeps the full name as the accessible one either way.
  def label(gameweek: nil)
    case key
    when GAMEWEEK then gameweek ? "Gameweek #{gameweek}" : "Next Gameweek"
    when UPCOMING then "Next #{WINDOW} Gameweeks"
    else "Rest of Season"
    end
  end

  def short_label(gameweek: nil)
    case key
    when GAMEWEEK then gameweek ? "GW#{gameweek}" : "Next GW"
    when UPCOMING then "Next #{WINDOW}"
    else "Season"
    end
  end

  # The distance said as a phrase, for the sentences that have to name it: "expected
  # points for the next five gameweeks". Written here so a page cannot label a number
  # with a stretch of football it was not worked out over, which is exactly what
  # happened when this was a yes-or-no: anything that was not the season was called
  # "this gameweek", and a five-week total was printed under it.
  def span
    case key
    when GAMEWEEK then "this gameweek"
    when UPCOMING then "the next #{WINDOW} gameweeks"
    else "the rest of the season"
    end
  end

  # The same thing where there is no room for it, as on a card.
  def short_span
    case key
    when GAMEWEEK then "this week"
    when UPCOMING then "next #{WINDOW}"
    else "rest of season"
    end
  end

  # Whether a score over this distance is a total that has to be read back to a week
  # before it can be graded or compared.
  def total? = divisor > 1

  def ==(other) = other.is_a?(Horizon) && other.key == key
  alias eql? ==
  def hash = key.hash
  def to_s = key
end
