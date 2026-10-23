class Pack
  SLOTS = %w[goalkeeper defender midfielder forward wildcard].freeze
  OUTFIELD = %w[defender midfielder forward].freeze

  Pair = Data.define(:slot, :cards, :shiny) do
    def shiny? = shiny
    def wildcard? = slot == "wildcard"
  end

  attr_reader :seed, :pairs

  def initialize(seed:, pairs:)
    @seed = seed
    @pairs = pairs
  end

  def size = pairs.size

  def shiny_index = pairs.index(&:shiny?)
end
