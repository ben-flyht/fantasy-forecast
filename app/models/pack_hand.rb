class PackHand
  LETTERS = %w[a b].freeze
  FORFEIT = "x"
  CHOICES = (LETTERS + [ FORFEIT ]).freeze
  FORMAT = /\A[abx]*\z/

  attr_reader :pack, :keeps

  def self.parse(pack, code)
    code = code.to_s
    return unless FORMAT.match?(code) && code.size <= pack.size

    new(pack, keeps: code.chars.map { |letter| LETTERS.index(letter) })
  end

  def initialize(pack, keeps:)
    @pack = pack
    @keeps = keeps
  end

  def picks
    @picks ||= pack.pairs.zip(keeps).first(keeps.size).map { |pair, keep| keep && pair.cards[keep] }
  end

  def kept = picks.compact

  def complete? = keeps.size == pack.size

  def current_pair = pack.pairs[keeps.size]

  def captain
    index = pack.shiny_index
    picks[index] if index && index < keeps.size
  end

  def code = keeps.map { |keep| keep ? LETTERS[keep] : FORFEIT }.join

  def keeping(choice) = self.class.new(pack, keeps: keeps + [ choice ])

  def forfeiting = keeping(nil)
end
