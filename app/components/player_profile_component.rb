# frozen_string_literal: true

# The facts beside the forecast: dead ball duties, fitness, age, and how long he
# has been at the club. None of it is rated, all of it is worth knowing.
#
# Set pieces earn top billing because they are the one thing here that reliably
# moves a return and the one thing the forecast does not read. A penalty taker at
# a side that wins them is a different player from his record alone.
class PlayerProfileComponent < ViewComponent::Base
  Fact = Struct.new(:label, :value, :notable, keyword_init: true) do
    def notable?
      !!notable
    end
  end

  def initialize(profile:)
    @profile = profile
  end

  def render?
    facts.any?
  end

  private

  attr_reader :profile

  def facts
    @facts ||= [ set_pieces, fitness, age, tenure, deadline ].compact
  end

  def set_pieces
    return if profile.set_pieces.empty?

    Fact.new(label: "Set pieces", value: profile.set_pieces.map(&:label).join(", "),
             notable: profile.set_pieces.any?(&:first_choice?))
  end

  def fitness
    return unless profile.doubtful?

    Fact.new(label: "Chance of playing", value: "#{profile.chance_of_playing}%", notable: true)
  end

  def age
    return unless profile.age

    Fact.new(label: "Age", value: profile.age.to_s)
  end

  # A signing date only earns its place when it is recent enough to matter: it is
  # then telling you his record was earned somewhere else.
  def tenure
    return unless profile.signed_on

    Fact.new(label: profile.new_signing? ? "New signing" : "At the club since",
             value: profile.signed_on.strftime("%b %Y"), notable: profile.new_signing?)
  end

  def deadline
    return unless profile.deadline&.future?

    Fact.new(label: "Deadline", value: "in #{helpers.time_ago_in_words(profile.deadline)}")
  end
end
