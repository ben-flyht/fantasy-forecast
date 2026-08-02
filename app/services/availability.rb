# How much of a run of gameweeks each player is expected to be fit for, as a
# share of them. Only players with something wrong get an entry: everybody else
# is fit and needs no opinion.
#
# FPL tells us whether a man can play this Saturday, never how long he is out
# for. Over one week those are the same question. Over a season they are not, and
# reading "0% chance of playing" as a verdict on the next nine months writes off
# a player with a fortnight's groin strain. That is why a fit-again Saliba was
# missing from a rest-of-season page entirely.
#
# So: where FPL names a return date, count the weeks after it. Where it does not,
# assume a long absence rather than a permanent one.
class Availability < ApplicationService
  FIT = "a".freeze
  DOUBTFUL = "d".freeze
  GONE = "u".freeze # left the league: on loan, sold abroad, released

  # A date FPL writes as "Expected back 21 Aug" or "Suspended until 6 Sep". The
  # year is never given, so it is taken from the day the news was posted.
  RETURN_DATE = /(?:Expected back|until)\s+(\d{1,2}\s+\w{3})/i
  CHANCE = /(\d+)%\s+chance of playing/i

  # What "Unknown return date" is worth, and it is a guess.
  #
  # FPL publishes nothing about severity, and of the players carrying that phrase
  # today, more than half are down as "Knee", which covers both a bruise and a
  # torn cruciate. A lookup table of injury types would be invention dressed up as
  # data, so we assume the bad end instead: better to leave out a player who could
  # have played than to recommend one who is not coming back.
  #
  # It stops being a guess once we have watched these flags clear. We already
  # store every player's fitness week by week, so by Christmas this can be the
  # measured figure rather than an assumed one.
  UNKNOWN_LAYOFF = 3.months

  # A doubt is about one weekend, not a season. Over a long horizon it costs him
  # that week and nothing more.
  ASSUMED_CHANCE = 75.0
  CERTAIN = 100.0

  def initialize(players, gameweeks:)
    @players = players
    @gameweeks = gameweeks.to_a
  end

  def call
    return {} if @gameweeks.empty?

    @players.each_with_object({}) do |player, shares|
      share = share_for(player)
      shares[player.id] = share unless share.nil?
    end
  end

  private

  def share_for(player)
    return nil if player.status.blank? || player.status == FIT
    return 0.0 if player.status == GONE
    return doubtful_share(player) if player.status == DOUBTFUL

    weeks_after(returns_on(player))
  end

  # He misses at most the coming week, and even that is not certain.
  def doubtful_share(player)
    chance = player.news.to_s[CHANCE, 1]&.to_f || ASSUMED_CHANCE
    ((@gameweeks.size - 1) + (chance / CERTAIN)) / @gameweeks.size
  end

  def weeks_after(date)
    @gameweeks.count { |gameweek| gameweek.start_time.to_date >= date } / @gameweeks.size.to_f
  end

  # Never sooner than the week after next, whatever the arithmetic says. FPL has
  # him at no chance for the coming one, and a flag posted months ago that is
  # still flying means he has not recovered on schedule, not that he is back.
  def returns_on(player)
    [ named_return(player) || flagged_on(player) + UNKNOWN_LAYOFF, earliest_return ].compact.max
  end

  def earliest_return
    @gameweeks.second&.start_time&.to_date
  end

  # "21 Aug" with no year. FPL posts the news before the return, so the date meant
  # is the first one on or after the day it was posted.
  def named_return(player)
    written = player.news.to_s[RETURN_DATE, 1]
    return nil if written.blank?

    posted = flagged_on(player)
    date = Date.parse("#{written} #{posted.year}")
    date < posted.to_date ? date.next_year : date
  rescue Date::Error
    nil
  end

  def flagged_on(player)
    player.news_added || Time.current
  end
end
