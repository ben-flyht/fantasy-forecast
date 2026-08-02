# FPL squeezes a player's name into one narrow column, so it abbreviates:
# "J.Timber", "Bruno G.", "Pedro Porro". Our rankings have two lines to play
# with, so we undo the squeeze: the given name on top, the name they are known
# by underneath, and never the same name twice.
class PlayerName
  NICKNAME = /\s'[^']*'/                 # Rodrigo 'Rodri'
  LEADING_INITIALS = /\A(?:\p{L}\.)+/     # J.Timber, P.M.Sarr
  TRAILING_INITIAL = /[.\s](\p{L})\.?\z/  # Bruno G., Tóth.A

  def initialize(first_name:, last_name:, short_name:)
    @first_name = first_name.to_s.strip
    @last_name = last_name.to_s.strip
    @short_name = short_name.to_s.strip
  end

  def display
    @display ||= without_given_name(spell_out(short_name))
  end

  # Whatever comes before the name they are known by: "Francisco Evanilson"
  # alongside "Evanilson" leaves us with "Francisco", and "Alysson Edward
  # Franco" alongside "Alysson" leaves us with nothing to add
  def given
    @given ||= first_name.gsub(NICKNAME, "").split.take_while { |part| !shown?(part) }.join(" ")
  end

  private

  attr_reader :first_name, :last_name, :short_name

  def spell_out(name)
    expand_trailing_initial(expand_leading_initials(name))
  end

  # "J.Timber" is Jurriën Timber, "O.Dango" is Dango Ouattara
  def expand_leading_initials(name)
    initials = name[LEADING_INITIALS]
    return name unless initials

    letters = initials.scan(/\p{L}/)
    return name.sub(LEADING_INITIALS, "") if letters.all? { |letter| first_name_initial?(letter) }

    surname_for(letters.first) || name
  end

  # "Bruno G." is Bruno Guimarães, "Tóth.A" is Alex Tóth
  def expand_trailing_initial(name)
    match = name.match(TRAILING_INITIAL)
    return name unless match

    without_initial = name.sub(TRAILING_INITIAL, "")
    return without_initial if first_name_initial?(match[1])

    surname = surname_for(match[1])
    surname ? "#{without_initial} #{surname}" : name
  end

  # "Pedro Porro" leads with the given name we are already showing above it
  def without_given_name(name)
    parts = name.split
    return name unless parts.size > first_name_parts.size
    return name unless same?(parts.first(first_name_parts.size).join(" "), first_name)

    parts.drop(first_name_parts.size).join(" ")
  end

  def shown?(part)
    display.split.any? { |shown| same?(part, shown) }
  end

  def first_name_initial?(initial)
    first_name_parts.any? { |part| same?(part.first, initial) }
  end

  def surname_for(initial)
    last_name.split.find { |part| same?(part.first, initial) }
  end

  def first_name_parts
    @first_name_parts ||= first_name.split
  end

  def same?(one, other)
    fold(one) == fold(other)
  end

  def fold(name)
    ActiveSupport::Inflector.transliterate(name).downcase
  end
end
