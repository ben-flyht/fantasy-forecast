# The fifteen laid out as a list, in two columns, beside the headline.
#
# Everything here is worked out from the name outwards. A phone draws the card at under
# a third of its size, nothing on it may fall below eleven pixels there, and that one
# rule sets every size on the card. The floor decides the column width, and the column
# width is what the photograph gets to have left over, rather than the other way round.
#
# Fifteen rows of two legible lines do not fit a letterbox, which is why the card is
# square. See ShareCard::SQUARE.
class ShareCard::TeamSheet
  # What a phone actually draws this at. On the site the card is capped at max-w-md and
  # a phone's container leaves about 358 of its 390 points.
  MOBILE_WIDTH = 358
  MOBILE_SCALE = MOBILE_WIDTH / ShareCard::WIDTH.to_f
  LEGIBLE_ON_A_PHONE = 11
  FLOOR = (LEGIBLE_ON_A_PHONE / MOBILE_SCALE).ceil          # 37

  # A chat scales it smaller still. Worth knowing what the same rule would cost there:
  # a card that cannot hold fifteen players and a photograph at once.
  CHAT_SCALE = 300 / ShareCard::WIDTH.to_f

  # Everything is at the floor, so what separates a name from a label from a price is
  # weight and colour. There is no room left for a hierarchy built out of small type.
  META_SIZE = FLOOR
  LABEL_SIZE = FLOOR

  # The mark is allowed just under the floor the words keep: a wordmark is recognised as
  # a shape rather than read letter by letter. Sized to the floor it came out 578 wide
  # and took half the card; at 46 its letters are 10px on a phone.
  LOGO_SIZE = 46

  COLUMNS = 2
  COLUMN_WIDTH = 392
  COLUMN_GAP = 28
  LEFT = 340
  TOP = 264

  # Both blocks are announced, or neither is: a labelled bench under an unlabelled
  # eleven reads as though the eleven were the whole squad and the bench an appendix.
  # A label is enough to say where one ends; a rule as well is saying it twice.
  STARTERS_LABEL = 210

  # Two lines of legible type is about seventy pixels of ink, so the pitch is what
  # decides whether a row reads as one player or as a wall of names.
  ROW_PITCH = 108

  SLANT_X = 36                                              # the slash and its white
  NAME_MAX = 44
  META_OFFSET = 42                                          # baseline to baseline

  # The photograph is given a right edge here rather than in the drawing, because a
  # photograph that reaches the names is the one thing this card must never do, and a
  # number in a template is a number somebody will nudge.
  GUTTER = 44
  PHOTO_RIGHT = LEFT - GUTTER

  BENCH_LABEL = 940
  BENCH_TOP = 994

  Block = Struct.new(:pick, :x, :y, keyword_init: true)

  def initialize(starters:, bench:, names:)
    @starters = starters
    @bench = bench
    @names = names
  end

  def starters = laid_out(@starters, TOP)
  def bench = laid_out(@bench, BENCH_TOP)

  def name_size
    @name_size ||= ShareCard.fitted_size(longest, width: room, max: NAME_MAX)
  end

  def room = COLUMN_WIDTH - SLANT_X

  def legible? = name_size >= FLOOR

  def right_edge = LEFT + (COLUMN_WIDTH * COLUMNS) + COLUMN_GAP

  private

  def longest = @names.values.max_by(&:length)

  def laid_out(picks, top)
    per = picks.size.fdiv(COLUMNS).ceil

    picks.each_with_index.map do |pick, index|
      Block.new(pick: pick,
                x: LEFT + ((index / per) * (COLUMN_WIDTH + COLUMN_GAP)),
                y: top + ((index % per) * ROW_PITCH))
    end
  end
end
