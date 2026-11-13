# frozen_string_literal: true

class LeaderboardRowComponent < ViewComponent::Base
  renders_one :figures

  def initialize(place:, name:, mine: false, pro: false, gap: false, **attributes)
    @place = place
    @name = name
    @mine = mine
    @pro = pro
    @gap = gap
    @attributes = attributes
  end

  private

  attr_reader :place, :attributes

  def gap? = @gap

  def pro? = @pro

  def name = @mine ? "#{@name} (you)" : @name

  def pro_title = "Rating of #{PackSeasonLeaderboard::PRO_RATING} or more this season"

  def classes
    [ "group px-4 py-3", ("bg-surface-muted" if @mine), attributes[:class] ].compact.join(" ")
  end
end
