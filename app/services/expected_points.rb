# What we expect each player to score in the coming gameweek, in points.
#
# One number, arrived at by multiplying the three things that decide a return:
#
#   minutes share  x  points per 90  x  the games ahead
#
# They multiply because they multiply in reality. A brilliant player who does not
# start scores nothing, and that falls out of the arithmetic rather than needing a
# weight to say so. A team playing twice gets two goes; a team not playing gets
# none. The answer is in real points, so it can be compared across positions and,
# unlike a score out of a hundred, checked against what actually happened.
#
# Inputs are passed in so the service stays pure and quick to test:
#   rankings         - ConsensusRanking::Ranking (player_id, position, team_id)
#   stats            - { player_id => { stat_type => Float } }
#   fixtures_by_team - { team_id => [{ difficulty:, opponent:, home: }] } this week's games
class ExpectedPoints
  STAT_TYPES = %w[
    season_minutes last_season_minutes chance_of_playing
    expected_goals_per_90 expected_goal_involvements_per_90 clean_sheets_per_90 saves_per_90
    selected_by_percent transfers_in transfers_out now_cost form points_per_game season_bonus
  ].freeze

  FULL_MATCH = 90.0
  FULLY_AVAILABLE = 100.0
  GAMEWEEKS_IN_SEASON = 38

  # Play seven minutes in ten of your side's football and you are a regular, which
  # is all this needs to establish. Past that the differences are availability luck
  # rather than role, and whether the luck is still running is the fitness flag's
  # business.
  REGULAR_SHARE = 0.7

  # Five matches of doubt, carried until the minutes outgrow it, so a rate built
  # from one lucky cameo cannot top the table.
  UNPROVEN_MINUTES = 450.0

  # A player who has just changed clubs has a minutes record belonging to somebody
  # else's team sheet. Three thousand minutes at Newcastle says nothing about
  # whether he is first choice at Tottenham, so his record is allowed to argue for
  # half a match and no more until he has played some football for the new side.
  NEW_CLUB_MINUTES = 0.5

  # FPL's scoring table, by position.
  GOAL = { "goalkeeper" => 10, "defender" => 6, "midfielder" => 5, "forward" => 4 }.freeze
  CLEAN_SHEET = { "goalkeeper" => 4, "defender" => 4, "midfielder" => 1, "forward" => 0 }.freeze
  ASSIST = 3
  SAVES_PER_POINT = 3.0

  # Two points for turning up and playing the hour, which almost every starter
  # does. It is the same for everyone, so it cannot separate two players who both
  # start, but it is most of what a forecast owes a reader: without it the numbers
  # are points above a baseline nobody sees rather than points.
  APPEARANCE = 2.0

  # How he has been scoring lately against how he scores normally, worth up to a
  # fifth either way. FPL's form is points per game over the last thirty days and
  # points_per_game is the same measure across the campaign, so the two divide
  # cleanly and the answer is "above or below his usual level".
  #
  # A fifth because form over four games is a loud, unreliable signal: enough to
  # separate a player in the middle of a run from one who has gone quiet, not
  # enough to make one haul outrank a season of evidence.
  FORM_SWING = 0.2

  # A kind fixture is worth about a tenth either way. More than that claims FPL's
  # one-to-five difficulty knows more than it does.
  FIXTURE_SWING = 0.05
  AVERAGE_DIFFICULTY = 3

  # What the crowd is willing to pay for him, and how far we let that speak.
  #
  # Ownership alone counts heads, and in a game with a hundred million to spend,
  # some of those heads are counting pennies: a cheap defender is owned partly
  # because somebody had to fill the slot. Ownership times price is what a manager
  # actually gave up to hold him, which deflates the enabler and rewards the
  # costly vote. It is not a perfect correction and nothing analytic is: strip
  # price out entirely and all that is left is "over-owned for how cheap he is",
  # which is the enabler signal again.
  #
  # The crowd is then treated as a forecast in its own right rather than as a
  # nudge to ours. Millions of managers, each choosing under a budget, produce an
  # ordering, and that ordering knows things a record cannot: who is fit, who has
  # a new role, who the manager talked up on Friday. So we take their order, read
  # off what a player at that rank is typically worth, and blend it with our own
  # answer.
  #
  # How much of the verdict the crowd gets is decided by what their vote cost
  # them. Owning a fifteen million pound striker is a decision a manager has had
  # to fund from the rest of his side, so it is worth listening to; owning a four
  # million pound defender is half a decision, because somebody had to fill the
  # slot. So the dearer the player, the more of the answer the crowd is given, and
  # the necessity at the cheap end is discounted rather than argued with.
  #
  # Choosing to spend good money on one player rather than another is a great deal
  # of ranking power, and at the dear end it decides most of the answer. It never
  # decides all of it: something has to be able to disagree, or the rankings become
  # purely self-fulfilling and can never spot anybody before the crowd does. These
  # are starting figures to be settled by results.
  # Costliness grows faster than price does. A hundred million buys one fifteen
  # million pound striker or three five million pound ones, so paying up is not
  # twice the decision at twice the price, it is more. Squaring it a little lifts
  # the player the crowd has dug deep for and pushes down the cheap pick half of
  # them own because somebody had to fill the slot.
  PRICE_POWER = 1.5

  CROWD_SHARE_MIN = 0.25
  CROWD_SHARE_MAX = 0.8

  # The cheapest tenth of a position, where ownership stops being a verdict.
  # Everybody needs a bench and somebody has to fill it, so a quarter of the game
  # owning the cheapest keeper is a budget decision, not a prediction that he will
  # play. Down here the crowd is allowed to mark a player down, which still means
  # something, but never to carry one up.
  CHEAPEST = 0.1

  # What this week's transfers say, measured against the people who actually own
  # him: a hundred thousand sales is nothing from two million owners and a rout
  # from six hundred thousand.
  #
  # Deliberately lopsided. Managers sell on news, and they get it before our data
  # does: a benching, a knock in training, a suspension nobody has filed yet. A
  # rush for the exit is close to a statement of fact, so it can halve a player on
  # the spot. Buying is speculation about what somebody might do, which is worth
  # far less, so it can only ever add a little.
  EXODUS_FLOOR = 0.5
  INFLOW_CEILING = 1.15

  # The knobs, gathered so a stored forecast can say which settings produced it and
  # so the optimiser has something to search over. FPL's scoring table is not among
  # them: five points for a midfielder's goal is a rule, not a parameter.
  def self.parameters
    {
      regular_share: REGULAR_SHARE, unproven_minutes: UNPROVEN_MINUTES,
      form_swing: FORM_SWING, fixture_swing: FIXTURE_SWING,
      crowd_share_min: CROWD_SHARE_MIN, crowd_share_max: CROWD_SHARE_MAX, price_power: PRICE_POWER,
      new_club_minutes: NEW_CLUB_MINUTES, cheapest: CHEAPEST,
      exodus_floor: EXODUS_FLOOR, inflow_ceiling: INFLOW_CEILING
    }
  end

  def initialize(rankings, stats:, fixtures_by_team:, season_started: true, gameweeks_played: nil,
                 managers: nil, movers: [])
    @rankings = rankings
    @stats = stats
    @fixtures_by_team = fixtures_by_team
    @season_started = season_started
    @gameweeks_played = weeks_of_football(gameweeks_played)
    @managers = managers.to_i
    @movers = movers.to_set
  end

  # How much football there has been to measure against. Before the season starts
  # that is last season's full campaign, which is what the minutes are read from;
  # counting the nought gameweeks played so far would make a regular out of anybody
  # who managed an hour last year.
  def weeks_of_football(played)
    return GAMEWEEKS_IN_SEASON unless @season_started

    [ played.to_i, 1 ].max
  end

  # => { player_id => { points: Float or nil, working: [{ label:, detail: }] } }
  def call
    @rankings.each_with_object({}) do |ranking, result|
      result[ranking.player_id] = forecast(ranking)
    end
  end

  private

  def forecast(ranking)
    ours = our_estimate(ranking)
    theirs = crowd_estimate(ranking)
    return { points: nil, working: {} } if ours.nil? && theirs.nil?

    points = blended(ranking, ours, theirs) * availability(ranking) * games_ahead(ranking) * transfer_factor(ranking)
    { points: points.round(1), working: working_for(ranking, ours, theirs) }
  end

  # What a player is worth in a single game, before the fixture and before this
  # week's news. Nil when there is no record to read.
  def our_estimate(ranking)
    share = minutes_share(ranking)
    return nil if share.nil?

    share * points_per_90(ranking)
  end

  # What a player standing where he stands with the crowd is typically worth, read
  # off our own figures for the position. Where we agree with them this changes
  # nothing; where we disagree, each pulls the other.
  def crowd_estimate(ranking)
    return nil if conviction(ranking).zero?

    curve = crowd_curve(ranking.position)
    place = crowd_order(ranking.position).index(ranking.player_id)
    return nil if curve.empty? || place.nil?

    curve[[ place, curve.size - 1 ].min]
  end

  # A player nobody can measure is left to the crowd; a player nobody owns is left
  # to us.
  def blended(ranking, ours, theirs)
    return theirs if ours.nil?
    return ours if theirs.nil?

    share = crowd_share(ranking)
    (1 - share) * ours + share * capped(ranking, ours, theirs)
  end

  # Among the cheapest in a position, backing can only count against a player. It
  # is the one place where being popular tells us nothing: the money had to go
  # somewhere.
  def capped(ranking, ours, theirs)
    bargain?(ranking) ? [ theirs, ours ].min : theirs
  end

  def bargain?(ranking)
    dearness(ranking) < CHEAPEST
  end

  # A costly vote is a considered one, so the dearer the player the more of the
  # answer his backing decides.
  def crowd_share(ranking)
    CROWD_SHARE_MIN + (CROWD_SHARE_MAX - CROWD_SHARE_MIN) * dearness(ranking)
  end

  # How dear he is for his position, as the share of his peers he costs more than.
  # Strictly more: twenty keepers sit on the four million pound floor, and counting
  # them as dearer than each other would hand the cheapest man in the game a third
  # of the way up the scale. Taken as a standing among them rather than as a fraction of the
  # range, because one fifteen million pound striker would otherwise make every
  # other expensive forward look cheap.
  def dearness(ranking)
    prices = position_prices(ranking.position)
    return 0.0 if prices.empty?

    prices.count { |other| other < price(ranking) } / prices.size.to_f
  end

  def position_prices(position)
    @position_prices ||= {}
    @position_prices[position] ||= in_position(position).map { |other| price(other) }.reject(&:zero?)
  end

  # The position's own figures, best first: the shape of what is on offer.
  def crowd_curve(position)
    @crowd_curve ||= {}
    @crowd_curve[position] ||= in_position(position).filter_map { |ranking| our_estimate(ranking) }.sort.reverse
  end

  # Everyone in the position, in the order the crowd has put its money. Players the
  # crowd has treated identically are separated by our own reading of them, so a
  # tie cannot hand somebody another player's standing by accident.
  def crowd_order(position)
    @crowd_order ||= {}
    @crowd_order[position] ||= in_position(position)
                               .sort_by { |ranking| [ -conviction(ranking), -our_estimate(ranking).to_f ] }
                               .map(&:player_id)
  end

  def in_position(position)
    @in_position ||= @rankings.group_by(&:position)
    @in_position[position] || []
  end

  # THE FIRST TERM: how much of a match his record says he plays, as a share of 90.
  # Whether he is fit to play it at all is asked later, of the finished answer,
  # because a man who is out scores nothing however highly anyone rates him.
  #
  # Nil when there is no record at all: a promoted or newly signed player is
  # unknown rather than expected to do nothing, and unknown must not be ranked as
  # though we had measured it.
  def minutes_share(ranking)
    played = minutes_played(ranking)
    return nil if played.nil?

    regular = [ played / regular_minutes, 1.0 ].min
    @movers.include?(ranking.player_id) ? [ regular, NEW_CLUB_MINUTES ].min : regular
  end

  def minutes_played(ranking)
    optional_stat(ranking, @season_started ? "season_minutes" : "last_season_minutes")
  end

  def regular_minutes
    @gameweeks_played * FULL_MATCH * REGULAR_SHARE
  end

  # Absent means fit. Reading this as a plain zero would mark every healthy player
  # unavailable.
  def availability(ranking)
    (optional_stat(ranking, "chance_of_playing") || FULLY_AVAILABLE) / FULLY_AVAILABLE
  end

  # THE SECOND TERM: what he is worth per 90 minutes, from what he actually does
  # rather than what he happened to score, priced with FPL's own scoring table.
  # Appearance points are left out: everyone in a position gets the same two.
  def points_per_90(ranking)
    APPEARANCE + scoring_per_90(ranking)
  end

  # What he adds beyond turning up. Shrunk for a thin record and moved by his
  # recent run, neither of which should touch the appearance points: those are
  # certain the moment he is on the pitch.
  def scoring_per_90(ranking)
    earned = goal_points(ranking) + assist_points(ranking) +
             clean_sheet_points(ranking) + save_points(ranking) + bonus_points(ranking)
    earned * credibility(ranking) * form_factor(ranking)
  end

  # Bonus is awarded per match to the three best performers, so it is not in any
  # per-90 rate FPL publishes and has to be worked out from his own totals.
  def bonus_points(ranking)
    played = minutes_played(ranking).to_f
    return 0.0 if played.zero?

    stat(ranking, "season_bonus") / (played / FULL_MATCH)
  end

  # Nought before a ball is kicked, and nought for a player with no record, both of
  # which read as no opinion rather than as a slump.
  def form_factor(ranking)
    recent = stat(ranking, "form")
    usual = stat(ranking, "points_per_game")
    return 1.0 if recent.zero? || usual.zero?

    (recent / usual).clamp(1 - FORM_SWING, 1 + FORM_SWING)
  end

  def goal_points(ranking)
    GOAL.fetch(ranking.position, 4) * goals(ranking)
  end

  # Involvements less the goals themselves, never negative however FPL rounds.
  def assist_points(ranking)
    created = [ stat(ranking, "expected_goal_involvements_per_90") - goals(ranking), 0.0 ].max
    ASSIST * created
  end

  def clean_sheet_points(ranking)
    CLEAN_SHEET.fetch(ranking.position, 0) * stat(ranking, "clean_sheets_per_90")
  end

  # Only ever anything for a keeper, so this needs no position of its own.
  def save_points(ranking)
    stat(ranking, "saves_per_90") / SAVES_PER_POINT
  end

  def goals(ranking)
    stat(ranking, "expected_goals_per_90")
  end

  # A rate over a handful of minutes is mostly luck, so it is pulled towards
  # nothing until the minutes back it up.
  def credibility(ranking)
    played = minutes_played(ranking).to_f
    played / (played + UNPROVEN_MINUTES)
  end

  # THE THIRD TERM: the games in front of him. One ordinary fixture is worth about
  # 1, a kind one a little more, and a team playing twice gets two goes at it. A
  # blank week is nought, which is the honest answer.
  def games_ahead(ranking)
    fixtures_for(ranking).sum { |fixture| 1 + (AVERAGE_DIFFICULTY - difficulty_of(fixture)) * FIXTURE_SWING }
  end

  # An unrated fixture counts as an ordinary one. Treating it as unplayable would
  # be a much bigger claim than the data supports.
  def difficulty_of(fixture)
    fixture[:difficulty] || AVERAGE_DIFFICULTY
  end

  def fixtures_for(ranking)
    @fixtures_by_team[ranking.team_id] || []
  end

  # What managers have committed to him: how many hold him, times what he cost them.
  def conviction(ranking)
    ownership(ranking) * price(ranking)**PRICE_POWER
  end

  # This week's traffic as a share of the people who hold him. Neutral until FPL
  # publishes a manager count, which it does not do before the season starts, and
  # neutral in a week where nobody has moved.
  def transfer_factor(ranking)
    owners = owners_of(ranking)
    return 1.0 if owners.zero?

    net = stat(ranking, "transfers_in") - stat(ranking, "transfers_out")
    (1 + net / owners).clamp(EXODUS_FLOOR, INFLOW_CEILING)
  end

  def owners_of(ranking)
    return 0.0 if @managers.zero?

    ownership(ranking) / 100.0 * @managers
  end

  def price(ranking)
    stat(ranking, "now_cost")
  end

  def ownership(ranking)
    stat(ranking, "selected_by_percent")
  end

  def stat(ranking, type)
    optional_stat(ranking, type) || 0.0
  end

  def optional_stat(ranking, type)
    @stats.dig(ranking.player_id, type)
  end

  # The figures the answer was multiplied from, as numbers. What they are called
  # and how they read is a job for the view.
  def working_for(ranking, ours, theirs)
    estimates(ranking, ours, theirs).merge(adjustments(ranking))
  end

  def estimates(ranking, ours, theirs)
    {
      minutes: (minutes_share(ranking).to_f * availability(ranking) * FULL_MATCH).round,
      per_90: points_per_90(ranking).round(2),
      ours: ours&.round(2),
      crowd: theirs&.round(2),
      crowd_share: crowd_share(ranking).round(3)
    }
  end

  def adjustments(ranking)
    {
      form: form_factor(ranking).round(3),
      games: games_ahead(ranking).round(3),
      transfers: transfer_factor(ranking).round(3),
      opponents: opponents_for(ranking)
    }
  end

  def opponents_for(ranking)
    fixtures_for(ranking).map do |fixture|
      { name: fixture[:opponent], home: fixture[:home], difficulty: fixture[:difficulty].to_i }
    end
  end
end
