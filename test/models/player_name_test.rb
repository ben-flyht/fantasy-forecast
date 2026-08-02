require "test_helper"

class PlayerNameTest < ActiveSupport::TestCase
  def name_for(first_name, last_name, short_name)
    player_name = PlayerName.new(first_name: first_name, last_name: last_name, short_name: short_name)
    [ player_name.given, player_name.display ]
  end

  test "keeps a plain name as it is" do
    assert_equal [ "Bukayo", "Saka" ], name_for("Bukayo", "Saka", "Saka")
  end

  test "drops the initial FPL uses in place of the first name" do
    assert_equal [ "Jurriën", "Timber" ], name_for("Jurriën", "Timber", "J.Timber")
    assert_equal [ "Pape Matar", "Sarr" ], name_for("Pape Matar", "Sarr", "P.M.Sarr")
    assert_equal [ "Alex", "Tóth" ], name_for("Alex", "Tóth", "Tóth.A")
  end

  test "spells out the initial FPL uses in place of the surname" do
    assert_equal [ "Bruno", "Guimarães" ], name_for("Bruno", "Guimarães Rodriguez Moura", "Bruno G.")
    assert_equal [ "Dango", "Ouattara" ], name_for("Dango", "Ouattara", "O.Dango")
  end

  test "does not repeat the first name in the display name" do
    assert_equal [ "Pedro", "Porro" ], name_for("Pedro", "Porro Sauceda", "Pedro Porro")
    assert_equal [ "Marc", "Guiu" ], name_for("Marc", "Guiu Paz", "Marc Guiu")
  end

  test "shows nothing above a player known by their given name" do
    assert_equal [ "", "Gabriel" ], name_for("Gabriel", "dos Santos Magalhães", "Gabriel")
    assert_equal [ "", "Joelinton" ], name_for("Joelinton Cássio", "Apolinário de Lira", "Joelinton")
    assert_equal [ "", "Rodrigo" ], name_for("Rodrigo 'Rodri'", "Hernandez Cascante", "Rodrigo")
  end

  test "keeps the first name of a player known by their middle name" do
    assert_equal [ "Francisco", "Evanilson" ], name_for("Francisco Evanilson", "de Lima Barbosa", "Evanilson")
    assert_equal [ "Igor", "Thiago" ], name_for("Igor Thiago", "Nascimento Rodrigues", "Thiago")
  end

  test "ignores accents when comparing names" do
    assert_equal [ "", "Yeremy" ], name_for("Yéremy", "Pino Santos", "Yeremy")
  end

  test "leaves an abbreviation it cannot spell out alone" do
    assert_equal [ "Junior", "Kroupi.Jr" ], name_for("Junior", "Kroupi", "Kroupi.Jr")
  end
end
