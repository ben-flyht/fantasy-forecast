class PackHand
  LETTERS = %w[a b].freeze
  BENCH_SIZE = 2
  FORMAT = /\A(?<keeps>[ab]{0,7})(?:-(?<bench>[0-6]{0,2}))?\z/

  attr_reader :pack, :keeps, :bench

  def self.parse(pack, code)
    match = FORMAT.match(code.to_s)
    return unless match

    keeps = match[:keeps].chars.map { |letter| LETTERS.index(letter) }
    bench = match[:bench].to_s.chars.map(&:to_i)
    new(pack, keeps: keeps, bench: bench) if legal?(pack, keeps, bench)
  end

  def self.legal?(pack, keeps, bench)
    return false if keeps.size > pack.size
    return bench.empty? if keeps.size < pack.size

    bench.each_index.all? { |place| new(pack, keeps: keeps, bench: bench.first(place)).benchable?(bench[place]) }
  end

  def initialize(pack, keeps:, bench: [])
    @pack = pack
    @keeps = keeps
    @bench = bench
  end

  def kept
    @kept ||= pack.pairs.zip(keeps).first(keeps.size).map { |pair, keep| pair.cards[keep] }
  end

  def picking? = keeps.size < pack.size
  def benching? = !picking? && bench.size < BENCH_SIZE
  def complete? = !picking? && bench.size == BENCH_SIZE

  def current_pair = pack.pairs[keeps.size]

  def captain
    index = pack.shiny_index
    kept[index] if index && index < keeps.size
  end

  def starters = kept.each_index.reject { |index| bench.include?(index) }.map { |index| kept[index] }
  def substitutes = bench.map { |index| kept[index] }

  def benchable?(index)
    return false unless benching? && kept[index] && !bench.include?(index)
    return false if kept[index] == captain

    legal_line_up?(starters - [ kept[index] ])
  end

  def code
    letters = keeps.map { |keep| LETTERS[keep] }.join
    picking? ? letters : "#{letters}-#{bench.join}"
  end

  def keeping(choice) = self.class.new(pack, keeps: keeps + [ choice ])
  def benching(index) = self.class.new(pack, keeps: keeps, bench: bench + [ index ])

  private

  def legal_line_up?(line_up)
    positions = line_up.map(&:position)
    positions.count("goalkeeper") == 1 && Pack::OUTFIELD.all? { |position| positions.include?(position) }
  end
end
