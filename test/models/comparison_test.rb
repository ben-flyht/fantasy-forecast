require "test_helper"

class ComparisonTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)        # fpl_id 200
    @palmer = players(:midfielder_two)   # fpl_id 201
    @injured = players(:injured_player)  # fpl_id 202
    @raya = players(:goalkeeper)         # fpl_id 100
  end

  test "a pair is spelled the same way whichever order it was asked in" do
    assert_equal Comparison.new(@salah, @palmer).slug, Comparison.new(@palmer, @salah).slug
  end

  test "the pair a pair used to be is the pair it still is" do
    assert_equal "#{@salah.to_param}-vs-#{@palmer.to_param}", Comparison.new(@salah, @palmer).slug
  end

  test "a side of two is joined by the word somebody would say" do
    comparison = Comparison.new([ @palmer, @salah ], @raya)

    assert_equal "#{@raya.to_param}-vs-#{@salah.to_param}-and-#{@palmer.to_param}", comparison.slug
  end

  test "every order of the same argument is sent to one spelling of it" do
    canonical = Comparison.new([ @salah, @palmer ], [ @raya, @injured ]).slug

    assert_equal canonical, Comparison.new([ @palmer, @salah ], [ @injured, @raya ]).slug
    assert_equal canonical, Comparison.new([ @injured, @raya ], [ @palmer, @salah ]).slug
  end

  test "an address is read back as the sides it names" do
    comparison = Comparison.parse("#{@salah.to_param}-and-#{@palmer.to_param}-vs-#{@raya.to_param}")

    assert_equal [ @raya ], comparison.left.players
    assert_equal [ @salah, @palmer ], comparison.right.players
  end

  test "a side of one is a player, and a side of two is nobody in particular" do
    comparison = Comparison.new(@salah, [ @palmer, @injured ])

    assert_equal @salah, comparison.left.player
    assert_nil comparison.right.player
  end

  test "a side can hold as many players as a move needs" do
    many = [ @salah, @palmer, @injured, @raya ].map(&:to_param).join("-and-")

    comparison = Comparison.parse("#{many}-vs-#{players(:brazilian).to_param}")

    assert_equal 4, comparison.left.size
    assert_equal 1, comparison.right.size
  end

  test "one name and no argument is not an address" do
    assert_raises(ActiveRecord::RecordNotFound) { Comparison.parse(@salah.to_param) }
  end

  test "a name we do not know is not found rather than guessed at" do
    assert_raises(ActiveRecord::RecordNotFound) { Comparison.parse("nobody-99999-vs-#{@salah.to_param}") }
  end

  test "buying the same player twice is not a question" do
    assert_not Comparison.new([ @salah, @palmer ], [ @salah, @raya ]).valid?
    assert_not Comparison.new(@salah, @salah).valid?
    assert Comparison.new([ @salah, @palmer ], [ @injured, @raya ]).valid?
  end

  test "a player against himself is still clearly about him" do
    assert_equal @salah, Comparison.new(@salah, @salah).one_player
    assert_nil Comparison.new([ @salah, @palmer ], [ @salah, @raya ]).one_player
  end

  test "a group knows it is one" do
    assert_not Comparison.new(@salah, @palmer).group?
    assert Comparison.new([ @salah, @palmer ], @raya).group?
  end

  test "the players are everybody named, whichever side they are on" do
    comparison = Comparison.new([ @salah, @palmer ], @raya)

    assert_equal [ @raya, @salah, @palmer ], comparison.players
  end
end
