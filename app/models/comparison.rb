# The two players a /compare address names.
#
# Salah or Palmer and Palmer or Salah are the same question, so the pair has one
# spelling and the other order is sent to it. Otherwise the two halves of the same
# argument would be two pages, each knowing half of what the one page would have
# known.
#
# The order is by FPL's own id: arbitrary, but it never moves, where a name can
# change with a transfer and a price changes every week.
class Comparison
  SEPARATOR = "-vs-".freeze

  attr_reader :left, :right

  def initialize(left, right)
    @left, @right = [ left, right ].sort_by(&:fpl_id)
  end

  # The pair an address names, whichever order it named them in.
  def self.parse(slug)
    left, right = slug.to_s.split(SEPARATOR, 2)
    raise ActiveRecord::RecordNotFound, "Not a pair: #{slug}" if right.blank?

    new(Player.includes(:team).from_param(left), Player.includes(:team).from_param(right))
  end

  def slug
    [ left.to_param, right.to_param ].join(SEPARATOR)
  end

  # Comparing a player with himself is not a question.
  def valid?
    left.id != right.id
  end

  def players
    [ left, right ]
  end
end
