# The facts about a player we report rather than rate.
#
# None of this is scored and none of it moves a forecast. It is what a reader
# needs beside the number to judge it for themselves: who takes the penalties,
# whether he is fit, how old he is, and whether he has been at the club long
# enough for his record to belong to it.
class PlayerProfile < ApplicationService
  # FPL publishes an order for each dead ball duty: 1 is the man who takes them.
  SET_PIECES = {
    "penalties_order" => "Penalties",
    "direct_freekicks_order" => "Free kicks",
    "corners_freekicks_order" => "Corners"
  }.freeze

  # Past third choice a duty says nothing: he is one injury and one substitution
  # away from a set piece he will never take.
  WORTH_MENTIONING = 3

  # How recently a player must have signed for his minutes to belong to somebody
  # else's team sheet. The same window the forecast itself uses to discount them,
  # so the page and the model agree about who is new. See Forecaster#movers.
  RECENTLY_SIGNED = 120

  FITNESS = "chance_of_playing".freeze

  Duty = Struct.new(:name, :order, keyword_init: true) do
    def first_choice?
      order == 1
    end

    def label
      first_choice? ? name : "#{name} (#{order.ordinalize})"
    end
  end

  def initialize(player:, gameweek: nil)
    @player = player
    @gameweek = gameweek
  end

  def call
    self
  end

  # The dead ball duties worth mentioning, the man who takes them first.
  def set_pieces
    @set_pieces ||= SET_PIECES.filter_map do |type, name|
      order = stats[type]&.round
      next if order.nil? || order.zero? || order > WORTH_MENTIONING

      Duty.new(name: name, order: order)
    end.sort_by(&:order)
  end

  # FPL's word on whether he can play, as a percentage. Nil where it has nothing
  # to say, which is FPL's way of saying he is fit.
  #
  # Read from the gameweek in question and no earlier one. FPL clears the flag by
  # publishing nothing at all once a player is well again, so a doubt carried
  # forward from September would still be casting one in April. See
  # Forecaster#fitness_of, which reads it the same way for the same reason.
  def chance_of_playing
    return unless @gameweek

    Statistic.find_by(player_id: @player.id, gameweek_id: @gameweek.id, type: FITNESS)&.value&.round
  end

  def doubtful?
    chance = chance_of_playing
    chance.present? && chance < 100
  end

  def age
    return unless @player.birth_date

    now = Date.current
    now.year - @player.birth_date.year - (now.yday < @player.birth_date.yday ? 1 : 0)
  end

  def signed_on
    @player.team_join_date
  end

  # A player whose minutes were earned somewhere else. Worth flagging, because it
  # is the one case where a long record says least about what happens next.
  def new_signing?
    return false unless signed_on

    signed_on > Date.current - RECENTLY_SIGNED
  end

  def deadline
    @gameweek&.start_time
  end

  private

  # A dead ball duty holds until the club says otherwise, so the latest reading is
  # the right one however long ago it was taken.
  def stats
    @stats ||= Statistic.where(player_id: @player.id, type: SET_PIECES.keys)
                        .latest_by_player
                        .fetch(@player.id, {})
  end
end
