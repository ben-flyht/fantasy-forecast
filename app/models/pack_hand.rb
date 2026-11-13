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

  def discards
    pack.pairs.zip(keeps).first(keeps.size).map { |pair, keep| keep.nil? ? [] : pair.cards.reject.with_index { |_, choice| choice == keep } }
  end

  def complete? = keeps.size == pack.size && keeps.all?

  def choice_at(index) = keeps[index]

  def captain
    index = pack.shiny_index
    picks[index] if index && index < keeps.size
  end

  def code = keeps.map { |keep| keep ? LETTERS[keep] : FORFEIT }.join
end
