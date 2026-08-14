require "test_helper"

class MatchupTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)        # fpl_id 200
    @palmer = players(:midfielder_two)   # fpl_id 201
    @injured = players(:injured_player)  # fpl_id 202
    @raya = players(:goalkeeper)         # fpl_id 100
  end

  test "a pair is spelled the same way whichever order it was asked in" do
    assert_equal Matchup.new(@salah, @palmer).slug, Matchup.new(@palmer, @salah).slug
  end

  # A comparison spells a player as a surname and his id, shorter than his own page's
  # first-and-surname address, since a full name on both sides of a trade runs long.
  test "a comparison spells a player as a surname and his id" do
    assert_equal "#{@salah.comparison_param}-vs-#{@palmer.comparison_param}", Matchup.new(@salah, @palmer).slug
  end

  # An older first-and-surname comparison link still resolves, by its id, to the same
  # comparison — and to its shorter spelling.
  test "an older full-name comparison link still resolves" do
    old = "#{@salah.to_param}-vs-#{@palmer.to_param}"

    assert_equal Matchup.new(@salah, @palmer).slug, Matchup.parse(old).slug
  end

  test "a side of two is joined by the word somebody would say" do
    comparison = Matchup.new([ @palmer, @salah ], @raya)

    assert_equal "#{@salah.comparison_param}-and-#{@palmer.comparison_param}-vs-#{@raya.comparison_param}", comparison.slug
  end

  # Within a side the order does not matter; the sides themselves are kept as written,
  # so a trade never swaps its columns.
  test "within a side the order does not matter, but the sides are kept" do
    canonical = Matchup.new([ @salah, @palmer ], [ @raya, @injured ]).slug

    assert_equal canonical, Matchup.new([ @palmer, @salah ], [ @injured, @raya ]).slug
    assert_not_equal canonical, Matchup.new([ @injured, @raya ], [ @palmer, @salah ]).slug
  end

  test "an address is read back as the sides it names" do
    comparison = Matchup.parse("#{@salah.to_param}-and-#{@palmer.to_param}-vs-#{@raya.to_param}")

    assert_equal [ @salah, @palmer ], comparison.left.players
    assert_equal [ @raya ], comparison.right.players
  end

  test "a side of one is a player, and a side of two is nobody in particular" do
    comparison = Matchup.new(@salah, [ @palmer, @injured ])

    assert_equal @salah, comparison.left.player
    assert_nil comparison.right.player
  end

  test "a side can hold as many players as a move needs" do
    many = [ @salah, @palmer, @injured, @raya ].map(&:to_param).join("-and-")

    comparison = Matchup.parse("#{many}-vs-#{players(:brazilian).to_param}")

    assert_equal 4, comparison.left.size
    assert_equal 1, comparison.right.size
  end

  test "one name and no argument is not an address" do
    assert_raises(ActiveRecord::RecordNotFound) { Matchup.parse(@salah.to_param) }
  end

  # A rail against an address hand-typed to name half the league: the count is refused
  # from the raw string, before a single player is looked up.
  test "a side naming more than the cap is refused before any lookup" do
    too_many = (1..(Matchup::MAX_PER_SIDE + 1)).map { |i| "player-#{i}" }.join("-and-")

    assert_raises(ActiveRecord::RecordNotFound) { Matchup.parse("#{too_many}-vs-#{@salah.to_param}") }
  end

  test "an empty address is empty, and a half-built one is not answerable" do
    assert Matchup.parse("-vs-").empty?

    building = Matchup.parse("#{@salah.to_param}-vs-")
    assert_not building.empty?
    assert_not building.answerable?
  end

  test "a distinct player each side is answerable, a duplicate across sides is not" do
    assert Matchup.new(@salah, @palmer).answerable?
    assert_not Matchup.new([ @salah, @palmer ], [ @salah, @raya ]).answerable?
  end

  test "a name we do not know is not found rather than guessed at" do
    assert_raises(ActiveRecord::RecordNotFound) { Matchup.parse("nobody-99999-vs-#{@salah.to_param}") }
  end

  test "buying the same player twice is not a question" do
    assert_not Matchup.new([ @salah, @palmer ], [ @salah, @raya ]).valid?
    assert_not Matchup.new(@salah, @salah).valid?
    assert Matchup.new([ @salah, @palmer ], [ @injured, @raya ]).valid?
  end

  test "a player against himself is still clearly about him" do
    assert_equal @salah, Matchup.new(@salah, @salah).one_player
    assert_nil Matchup.new([ @salah, @palmer ], [ @salah, @raya ]).one_player
  end

  test "a group knows it is one" do
    assert_not Matchup.new(@salah, @palmer).group?
    assert Matchup.new([ @salah, @palmer ], @raya).group?
  end

  test "the players are everybody named, whichever side they are on" do
    comparison = Matchup.new([ @salah, @palmer ], @raya)

    assert_equal [ @salah, @palmer, @raya ], comparison.players
  end
end
