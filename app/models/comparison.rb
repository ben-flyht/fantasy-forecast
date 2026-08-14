# The two sides a /compare address names.
#
# A side is usually one player, and sometimes the two or three you would buy in one
# move: a manager holding two free transfers is not choosing between two players, he
# is choosing between two pairs of them, and the addition is the arithmetic this site
# exists to do for him.
#
# Salah or Palmer and Palmer or Salah are the same question, so a comparison has one
# spelling and every other order is sent to it. Otherwise the two halves of the same
# argument would be two pages, each knowing half of what the one page would have
# known.
#
# The order is by FPL's own id: arbitrary, but it never moves, where a name can
# change with a transfer and a price changes every week.
class Comparison
  SEPARATOR = "-vs-".freeze

  # What joins the players on one side. Spelled the way somebody would say it, because
  # an address here is read as often as it is clicked.
  JOINER = "-and-".freeze

  # How many players a side can name. Not a limit on the question — a whole squad is
  # more than anyone weighs in one move — but a rail against an address hand-typed to
  # name half the league, counted from the raw string before a single player is looked
  # up so a pathological request is refused rather than run.
  MAX_PER_SIDE = 15

  # One half of the argument: a player, or the players you would buy together.
  class Side
    attr_reader :players

    # A side may be written as a player, a list of them, or one of these already, so
    # that a caller with a pair in its hands does not have to know this class exists.
    def self.wrap(value)
      value.is_a?(Side) ? value : new(Array(value))
    end

    def initialize(players)
      @players = players.sort_by(&:fpl_id)
    end

    def slug
      players.map(&:comparison_param).join(JOINER)
    end

    def size = players.size

    def single? = size == 1

    # The player this side is, where it is only one. A side of two is not a player,
    # and asking it for one comes back empty rather than coming back with half of it.
    def player
      players.first if single?
    end

    # What the side sorts by, which is the lowest id on it. A side still being filled
    # has nobody to sort by yet.
    def fpl_id = players.first&.fpl_id
  end

  attr_reader :left, :right

  # A one-against-one is symmetric — Salah or Palmer is Palmer or Salah — so its two
  # sides are ordered by FPL id and the other spelling redirects to it. A trade is read
  # in the order it is written and its sides stay where they were put, so adding or
  # dropping a player never makes the two columns swap places. The players within a
  # side are always ordered, so only the sides themselves are left alone.
  def initialize(left, right)
    sides = [ Side.wrap(left), Side.wrap(right) ]
    @left, @right = sides.all?(&:single?) ? sides.sort_by(&:fpl_id) : sides
  end

  # The sides an address names, whichever order it named them in. A side may be empty
  # — "salah-200-vs-" — because a comparison is built a player at a time and the address
  # keeps up with it; that address has no answer yet, only a side still being filled.
  def self.parse(slug)
    left, right = slug.to_s.split(SEPARATOR, 2)
    raise ActiveRecord::RecordNotFound, "Not a comparison: #{slug}" if right.nil?

    new(side_from(left), side_from(right))
  end

  # One side of an address. The split is on " and " as an address spells it, which a
  # player's own name cannot contain: names are parameterized and the id on the end of
  # each is the part that identifies him. A split in the wrong place therefore loses an
  # id and is not found, rather than quietly finding somebody else. An empty half is a
  # side nobody has been put on yet.
  def self.side_from(half)
    params = half.split(JOINER)
    raise ActiveRecord::RecordNotFound, "Too many on a side: #{half}" if params.size > MAX_PER_SIDE

    Side.new(params.map { |param| Player.includes(:team).from_param(param) })
  end
  private_class_method :side_from

  def sides = [ left, right ]

  def slug
    sides.map(&:slug).join(SEPARATOR)
  end

  def players
    sides.flat_map(&:players)
  end

  # More than one player on a side. A different question from "him or him", and a
  # page nobody arrives at from a search, so it is kept out of the index.
  def group?
    sides.any? { |side| !side.single? }
  end

  # No player on either side: the empty builder, not a comparison.
  def empty?
    players.empty?
  end

  # A player on each side, and nobody named twice, so there is an answer to draw. A
  # side still being filled has no answer yet, only a builder.
  def answerable?
    left.players.any? && right.players.any? && valid?
  end

  # Comparing a player with himself is not a question, and neither is buying one of
  # them twice.
  def valid?
    players.map(&:id).uniq.size == players.size
  end

  # The one player an address names, where both sides name only him. Not a question,
  # but there is no doubt who it is about, so there is a page to send it to.
  def one_player
    return unless left.single? && right.single?

    left.player if left.player.id == right.player.id
  end
end
