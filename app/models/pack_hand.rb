class PackHand
  LETTERS = %w[a b].freeze
  FORMAT = /\A[ab]*\z/

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

  def kept
    @kept ||= pack.pairs.zip(keeps).first(keeps.size).map { |pair, keep| pair.cards[keep] }
  end

  def complete? = keeps.size == pack.size

  def current_pair = pack.pairs[keeps.size]

  def captain
    index = pack.shiny_index
    kept[index] if index && index < keeps.size
  end

  def code = keeps.map { |keep| LETTERS[keep] }.join

  def keeping(choice) = self.class.new(pack, keeps: keeps + [ choice ])
end
