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
class ExpectedPoints < ApplicationService
  STAT_TYPES = %w[
    season_minutes last_season_minutes chance_of_playing
    expected_goals_per_90 expected_goal_involvements_per_90 clean_sheets_per_90 saves_per_90
    expected_goals_conceded_per_90 defensive_contribution_per_90
    selected_by_percent transfers_in transfers_out now_cost form points_per_game season_bonus
    last_season_expected_goals_per_90 last_season_expected_goal_involvements_per_90
    last_season_clean_sheets_per_90 last_season_saves_per_90 last_season_bonus
    last_season_expected_goals_conceded_per_90 last_season_defensive_contribution_per_90
  ].freeze

  # Where each measurement is read from before a ball is kicked.
  #
  # All of these describe the same football, so they have to come from the same
  # season. Take a player's minutes from last season and his scoring rate from a
  # season he spent outside the league and he is credited with a full campaign of
  # turning up and doing nothing, which is how a promoted club's defender came to
  # outrank the man half the game had picked ahead of him. FPL also zeroes the
  # current-season fields over the summer, so reading them then hands every player
  # in the game the same bare appearance points.
  LAST_SEASON = {
    "season_minutes" => "last_season_minutes",
    "season_bonus" => "last_season_bonus",
    "expected_goals_per_90" => "last_season_expected_goals_per_90",
    "expected_goal_involvements_per_90" => "last_season_expected_goal_involvements_per_90",
    "clean_sheets_per_90" => "last_season_clean_sheets_per_90",
    "saves_per_90" => "last_season_saves_per_90",
    "expected_goals_conceded_per_90" => "last_season_expected_goals_conceded_per_90",
    "defensive_contribution_per_90" => "last_season_defensive_contribution_per_90"
  }.freeze

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
  #
  # That caution is right for the coming week and too harsh for the rest of the
  # season, by when an established signing will long since have settled in. A
  # rest-of-season horizon lifts the cap so his record does more of the talking.
  NEW_CLUB_MINUTES = 0.5

  # How much of the game has to own a new signing before we take it that he has
  # walked into the side.
  #
  # The cap above is an admission that we do not know whether he starts, and that
  # is the one question the crowd answers better than any record can: managers do
  # not spend a squad place on a man who sits out. So where we have said "his
  # minutes belong to another club's team sheet", their money is allowed to say
  # "and he is first choice at this one".
  #
  # It is deliberately the narrowest use we could make of ownership. It applies
  # only where we have already confessed to guessing, it can only lift a player
  # and never mark him down, and it stops at a regular's share: backing may
  # establish that a man plays, never that he is any good, which is what his
  # record is for.
  #
  # A tenth of the game is a lot of managers when the average player is owned by
  # two per cent of it. A starting figure, to be settled by what actually happens
  # to these players' minutes.
  NAILED_ON = 10.0

  # FPL's scoring table, by position.
  GOAL = { "goalkeeper" => 10, "defender" => 6, "midfielder" => 5, "forward" => 4 }.freeze
  CLEAN_SHEET = { "goalkeeper" => 4, "defender" => 4, "midfielder" => 1, "forward" => 0 }.freeze

  # The other side of a clean sheet, and a separate rule rather than the same one
  # read backwards: a keeper or defender loses a point for every second goal his
  # side concedes, whether or not the sheet was ever going to be clean. Nobody
  # further up the pitch pays for them.
  CONCEDED = { "goalkeeper" => 1, "defender" => 1, "midfielder" => 0, "forward" => 0 }.freeze

  # The other half of the scoring table, and the only part of it that is not paid
  # by the goal: two points for clearing a bar of defensive actions in a single
  # match, ten of them at the back and twelve further up, where a player has to
  # win the ball back rather than merely be near it. Goalkeepers are not paid for
  # it at all.
  DEFENSIVE_POINTS = 2.0
  DEFENSIVE_ACTIONS = { "defender" => 10, "midfielder" => 12, "forward" => 12 }.freeze

  # How many players a club needs before its own figure is worth more than what
  # we would otherwise assume of it. See #club_rates.
  CLUB_EVIDENCE = 3

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
  #
  # A fifth at the start, and more as the season goes on. In August the only
  # evidence is last year's, and a summer's form cannot be allowed to talk over a
  # whole campaign of it. By the spring the running is the evidence, last season
  # is the memory, and the swing has widened to let what is happening now say more
  # than what happened before. See #form_swing.
  FORM_SWING = 0.2
  FORM_SWING_GROWTH = 0.3

  # How much the opponent matters, which depends entirely on what a player is
  # paid for.
  #
  # This used to be one number applied to the whole score, and that was wrong
  # three ways at once. Two points for turning up are the same against Arsenal as
  # against a promoted side, and no opponent can touch them. A clean sheet is the
  # opposite: who you are playing decides almost all of it, and the rate varies
  # about threefold between the kindest fixture in the game and the cruellest. A
  # goalkeeper's saves run the other way entirely, because a hard afternoon is a
  # busy one, and marking his saves down for a tough fixture had us paying him
  # least exactly when he had most to do.
  #
  # So the fixture is applied where the opponent has a say, in proportion to how
  # much say he has, and nowhere else. Difficulty runs one to five about a middle
  # of three, so the half-range below turns that into a number from minus one for
  # the worst fixture to plus one for the best.
  # Each step of difficulty multiplies rather than adds, because that is how the
  # real rates behave: a clean sheet is not a fixed number of percentage points
  # harder against each better side, it is a fraction as likely.
  AVERAGE_DIFFICULTY = 3

  # Clean sheets swing hardest, and the fixture is given a decisive say in them.
  # A step of three-quarters per grade opens a wide gap between the kindest
  # afternoon and the cruellest, wider than the raw historical rates on their own,
  # so an easy game and a very hard one are told firmly apart rather than nudged.
  CLEAN_SHEET_STEP = 1.75

  # Goals and assists move less than clean sheets, but are no longer treated as
  # near fixture-proof. A good forward still scores against good sides, yet a kind
  # fixture is now allowed to lift him and a cruel one to weigh on him by a margin
  # a reader can feel.
  ATTACK_STEP = 1.4

  # Saves run the other way: the afternoon that denies a goalkeeper his clean
  # sheet is the afternoon that keeps him busy.
  #
  # How much busier is the whole question, and it was answered far too generously.
  # At 0.62 the cruellest fixture in the game handed a keeper two and a half times
  # his usual saves, which no goalkeeper has ever managed: the best sides take
  # something like a third more shots than an ordinary opponent, not twice as
  # many. The arithmetic then said the same thing every week, because three saves
  # are worth one point and a clean sheet is worth four: a Bournemouth keeper away
  # at Man City was the second best pick in the game, ahead of every keeper with
  # an easy afternoon, purely for the shots he was going to face.
  #
  # So the step is back where the shot counts put it. A hard fixture still costs a
  # keeper less than it costs his defenders, which is the true part of the idea,
  # and it is still a cost.
  SAVE_STEP = 0.87

  # Goals conceded run with the opponent rather than against him, so this sits
  # below one like the saves it comes with. A step of a quarter puts about half
  # again as many goals past a side facing the champions as facing an ordinary
  # team, which is roughly what the goal records show. It is deliberately gentler
  # than the clean sheet step: whether a sheet stays clean at all turns on the
  # opponent far more than how many goals eventually go past.
  CONCEDE_STEP = 0.8

  # Defending runs with the opponent, like a goalkeeper's saves: the better the
  # side in front of you, the more there is to do. Gently, though, because how
  # much a team defends is mostly a matter of how it plays rather than who it is
  # playing, and the tables bear that out: the busiest defensive sides in the
  # league are mid-table, not the worst in it.
  DEFENSIVE_STEP = 0.9

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
  # of ranking power, and before a ball is kicked it is the best forecast there
  # is. A price is FPL's own valuation, set by people who watch these players for
  # a living and updated every day the game is open; it remembers the season an
  # injured man had before he was hurt, which his own thin record has forgotten.
  # So the order the money makes leads, and a record is only allowed to nudge it.
  #
  # Costliness grows faster than price does. A hundred million buys one fifteen
  # million pound striker or three five million pound ones, so paying up is not
  # twice the decision at twice the price, it is more. Raising it to two and a half
  # lifts the player the crowd has dug deep for well clear of the cheap pick half
  # of them own because somebody had to fill the slot: it takes the dear-and-owned
  # over the cheap-and-owned, and leaves the dear-and-unowned where his lack of
  # backing puts him, which is how a man nobody starts stays down.
  #
  # It fades as the season runs. A price is a forecast, and a forecast is at its
  # best when it is all there is; once results are in they re-price the game
  # slower than the pitch does, so what a player is now doing is trusted over what
  # he cost. See #price_power.
  PRICE_POWER = 2.5
  PRICE_POWER_FLOOR = 1.5

  # How far a record may pull a player off the order his price and backing make.
  #
  # The market leads and the record nudges: a twentieth either way at the start,
  # so a thin or a flattering season can shade a player up or down without
  # overturning what he cost. Anyone the game has funded and picked keeps his
  # standing; his own numbers adjust it, they do not decide it. This is what stops
  # a healthy, cheap enabler's record vaulting an expensive man the crowd is
  # certain of but the record has barely seen.
  #
  # The band widens through the season, because a record earns the right to argue
  # as it grows. In August it is last year's and holds no surprises the price has
  # not already priced; by the spring it is the surest thing we have, and it is
  # let further off the market accordingly. See #nudge_width.
  CLAMP_WIDTH = 0.05
  PERF_GROWTH = 0.15

  # The cheapest tenth of a position, where ownership stops being a verdict on
  # quality. Everybody needs a bench and somebody has to fill it, so a quarter of
  # the game owning the cheapest keeper is a budget decision rather than a claim
  # that he is any good. It is still a claim that he plays, which is why these
  # players are judged against each other rather than ignored. See #bracket_of.
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
      form_swing: FORM_SWING, form_swing_growth: FORM_SWING_GROWTH,
      clean_sheet_step: CLEAN_SHEET_STEP, attack_step: ATTACK_STEP, save_step: SAVE_STEP,
      concede_step: CONCEDE_STEP, defensive_step: DEFENSIVE_STEP, club_evidence: CLUB_EVIDENCE,
      clamp_width: CLAMP_WIDTH, perf_growth: PERF_GROWTH,
      price_power: PRICE_POWER, price_power_floor: PRICE_POWER_FLOOR,
      new_club_minutes: NEW_CLUB_MINUTES, nailed_on: NAILED_ON, cheapest: CHEAPEST,
      exodus_floor: EXODUS_FLOOR, inflow_ceiling: INFLOW_CEILING
    }
  end

  def initialize(rankings, stats:, fixtures_by_team:, season_started: true, gameweeks_played: nil,
                 managers: nil, movers: [], fitness: {},
                 clamp_width: CLAMP_WIDTH, new_club_minutes: NEW_CLUB_MINUTES)
    @rankings = rankings
    @stats = stats
    @fixtures_by_team = fixtures_by_team
    @season_started = season_started
    @fitness = fitness
    @gameweeks_played = gameweeks_played.to_i
    @managers = managers.to_i
    @movers = movers.to_set
    @clamp_width = clamp_width
    @new_club_minutes = new_club_minutes
  end

  # How far into the season we are, nought before it starts and one at its end.
  # The dial the record earns its say on: how wide a record may argue, how much a
  # recent run counts, and how far a price still leads. See #nudge_width,
  # #form_swing and #price_power.
  def season_progress
    return 0.0 unless @season_started

    (@gameweeks_played / GAMEWEEKS_IN_SEASON.to_f).clamp(0.0, 1.0)
  end

  # A twentieth at the start, widening as a record grows into something worth
  # hearing over the price that leads it.
  def nudge_width
    @clamp_width + PERF_GROWTH * season_progress
  end

  # Two and a half at the start, easing back towards a plain squaring as results
  # come in and re-price the game themselves.
  def price_power
    PRICE_POWER - (PRICE_POWER - PRICE_POWER_FLOOR) * season_progress
  end

  # A fifth at the start, widening as the running becomes the evidence.
  def form_swing
    FORM_SWING + FORM_SWING_GROWTH * season_progress
  end

  # How much football there has been to measure against. Before the season starts
  # that is last season's full campaign, which is what the minutes are read from;
  # counting the nought gameweeks played so far would make a regular out of anybody
  # who managed an hour last year.
  def weeks_of_football
    return GAMEWEEKS_IN_SEASON unless @season_started

    [ @gameweeks_played, 1 ].max
  end

  # => { player_id => { points: Float or nil, working: [{ label:, detail: }] } }
  def call
    @rankings.each_with_object({}) do |ranking, result|
      result[ranking.player_id] = forecast(ranking)
    end
  end

  # What one fixture is worth to a player against an ordinary one, exposed so a
  # projection can weigh a run of upcoming games by the same fixture maths the
  # forecast itself uses. One means an average opponent; above one is kinder.
  def fixture_worth(ranking, fixture)
    worth_of(ranking, fixture)
  end

  private

  def forecast(ranking)
    ours = our_estimate(ranking)
    theirs = crowd_estimate(ranking)
    return { points: nil, working: {} } if ours.nil? && theirs.nil?

    points = blended(ranking, ours, theirs) * availability(ranking) * games_ahead(ranking) * transfer_factor(ranking)
    { points: points, working: working_for(ranking, ours, theirs) }
  end

  # What a player is worth in a single game, before the fixture and before this
  # week's news. Nil when there is no record to read.
  def our_estimate(ranking)
    share = minutes_share(ranking)
    return nil if share.nil?

    share * points_per_90(ranking)
  end

  # What a player standing where he stands with the crowd is typically worth, read
  # off our own figures for the players he is judged against. Where we agree with
  # them this changes nothing; where we disagree, each pulls the other.
  def crowd_estimate(ranking)
    return nil if conviction(ranking).zero?

    peers = bracket_of(ranking)
    curve = crowd_curve(peers)
    place = crowd_place(peers, ranking.player_id)
    return nil if curve.empty? || place.nil?

    curve[[ place, curve.size - 1 ].min]
  end

  # The market leads and the record nudges. What a player cost and how the game
  # has backed him set where he stands; his own numbers may then shade that up or
  # down, but only within a band, so a record cannot overturn the money. See
  # #nudge_width for the band and PRICE_POWER for why the money is trusted to lead.
  #
  # A player nobody can measure is left to the crowd; a player nobody owns is left
  # to us; and a player who cannot play is judged on his record alone, his backing
  # having collapsed on the same news that ruled him out. See #ruled_out?.
  def blended(ranking, ours, theirs)
    return theirs if ours.nil?
    return ours if theirs.nil?
    return ours if ruled_out?(ranking)

    theirs * nudge(ours, theirs)
  end

  # How far the record moves the market: the record over the market, held inside
  # the band. One means they agree; the band's edges are the most a record is let
  # say against what a player cost and how he is owned.
  def nudge(ours, theirs)
    return 1.0 if theirs.zero?

    (ours / theirs).clamp(1 - nudge_width, 1 + nudge_width)
  end

  # Who a player's backing is measured against.
  #
  # Ownership means two different things depending on price. At the top of a
  # position it says a manager thinks this player is worth funding from the rest
  # of his side. At the bottom it mostly says he plays: somebody has to fill the
  # slot, so the game piles into whichever cheap defender is nailed on, and that
  # is a statement about the team sheet rather than about quality.
  #
  # Read against the whole position, an enabler is promoted into the company of
  # players managers actually paid for. Read against the other cheap players, the
  # same backing answers the only question worth asking of them, which is which
  # of them starts. So the cheap are ranked among themselves, and the best the
  # crowd can say of one is that he is the best of the cheap.
  #
  # This used to be a cap: among the cheapest, backing could only ever count
  # against a player, never for him. That kept enablers down and also made the
  # crowd mute exactly where it knows most, so two four million pound defenders
  # at the same club could not be told apart by the forty-fold difference in how
  # many managers had picked them.
  def bracket_of(ranking)
    [ ranking.position, bargain?(ranking) ]
  end

  def in_bracket(bracket)
    position, cheap = bracket
    in_position(position).select { |other| bargain?(other) == cheap }
  end

  def bargain?(ranking)
    dearness(ranking) < CHEAPEST
  end

  # Whether FPL has said he cannot play the coming week.
  #
  # His ownership has collapsed because of that same news, so letting the crowd
  # speak charges him for the injury twice: once in his availability, and again
  # in an ordering that is only low because he is hurt. Saliba is our own third
  # or fourth best defender on the record, and a rest-of-season page had him
  # sixty-eighth, most of which was managers selling a man we had already marked
  # unfit.
  #
  # So on a player who cannot play, their money tells us nothing we have not
  # already counted, and his own record does the talking. What being out costs
  # him is then one honest number rather than two vague ones multiplied: see
  # Availability.
  #
  # It changes nothing in the weekly forecast, where being ruled out takes him to
  # nought whatever anybody thinks of him.
  def ruled_out?(ranking)
    optional_stat(ranking, "chance_of_playing")&.zero?
  end

  # How dear he is for his position, as the share of his peers he costs more than.
  # Strictly more: twenty keepers sit on the four million pound floor, and counting
  # them as dearer than each other would hand the cheapest man in the game a third
  # of the way up the scale. Taken as a standing among them rather than as a fraction of the
  # range, because one fifteen million pound striker would otherwise make every
  # other expensive forward look cheap.
  def dearness(ranking)
    @dearness ||= {}
    @dearness[ranking.player_id] ||= dearness_of(ranking)
  end

  def dearness_of(ranking)
    prices = position_prices(ranking.position)
    return 0.0 if prices.empty?

    cost = price(ranking)
    prices.count { |other| other < cost } / prices.size.to_f
  end

  def position_prices(position)
    @position_prices ||= {}
    @position_prices[position] ||= in_position(position).map { |other| price(other) }.reject(&:zero?)
  end

  # The bracket's own figures, best first: the shape of what is on offer in it.
  def crowd_curve(bracket)
    @crowd_curve ||= {}
    @crowd_curve[bracket] ||= in_bracket(bracket).filter_map { |ranking| our_estimate(ranking) }.sort.reverse
  end

  # Everyone in the bracket, in the order the crowd has put its money. Players the
  # crowd has treated identically are separated by our own reading of them, so a
  # tie cannot hand somebody another player's standing by accident.
  def crowd_order(bracket)
    @crowd_order ||= {}
    @crowd_order[bracket] ||= in_bracket(bracket)
                              .sort_by { |ranking| [ -conviction(ranking), -our_estimate(ranking).to_f ] }
                              .map(&:player_id)
  end

  # Where in that order a player stands. Asked of every player in the bracket, so
  # kept as a lookup rather than a scan of the order for each of them.
  def crowd_place(bracket, player_id)
    @crowd_places ||= {}
    @crowd_places[bracket] ||= crowd_order(bracket).each_with_index.to_h
    @crowd_places[bracket][player_id]
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
    return regular unless @movers.include?(ranking.player_id)

    [ [ regular, @new_club_minutes ].min, settled_in(ranking) ].max
  end

  # What a signing's backing says about the team sheet. See NAILED_ON.
  def settled_in(ranking)
    REGULAR_SHARE * (ownership(ranking) / NAILED_ON).clamp(0.0, 1.0)
  end

  def minutes_played(ranking)
    optional_stat(ranking, season_or_last("season_minutes"))
  end

  # What he did, read from whichever season we are measuring. See LAST_SEASON.
  def record(ranking, type)
    stat(ranking, season_or_last(type))
  end

  def season_or_last(type)
    @season_started ? type : LAST_SEASON.fetch(type)
  end

  def regular_minutes
    weeks_of_football * FULL_MATCH * REGULAR_SHARE
  end

  # Whether he can play at all, which multiplies the finished answer.
  #
  # For the coming week that is FPL's fitness flag, and absent means fit: reading
  # a missing figure as a plain zero would mark every healthy player unavailable.
  # Over a longer horizon the question changes from "is he fit on Saturday" to
  # "how much of this is he fit for", and the caller answers it. See Availability.
  def availability(ranking)
    return @fitness[ranking.player_id] if @fitness.key?(ranking.player_id)

    (optional_stat(ranking, "chance_of_playing") || FULLY_AVAILABLE) / FULLY_AVAILABLE
  end

  # THE SECOND TERM: what he is worth per 90 minutes, from what he actually does
  # rather than what he happened to score, priced with FPL's own scoring table.
  # Appearance points are left out: everyone in a position gets the same two.
  # Against nobody in particular unless a fixture is named, which is how the
  # crowd's curve and a player's own standing are read: both are about what he is
  # worth on an ordinary afternoon.
  # A fixture is only ever read for how hard it is, so a player is worth the same
  # in any two matches of the same difficulty and is worked out once for each. Over
  # a season that is six answers a player rather than one per fixture, and it is
  # the whole of the saving in every rate underneath it.
  def points_per_90(ranking, fixture = nil)
    @points_per_90 ||= {}
    @points_per_90[[ ranking.player_id, fixture && difficulty_of(fixture) ]] ||=
      APPEARANCE + scoring_per_90(ranking, fixture)
  end

  # What he adds beyond turning up. Shrunk for a thin record and moved by his
  # recent run, neither of which should touch the appearance points: those are
  # certain the moment he is on the pitch.
  def scoring_per_90(ranking, fixture = nil)
    earned_against(ranking, fixture) * credibility(ranking) * form_factor(ranking)
  end

  # Each part of what he earns, moved by however much the opponent has to say
  # about that part. Bonus is left where it is: it is awarded for being among the
  # best three on the day, which is a comparison with the other twenty-one men on
  # the pitch rather than with the badge on their shirts.
  def earned_against(ranking, fixture)
    attacking_points(ranking) * swing(ATTACK_STEP, fixture) +
      clean_sheet_points(ranking) * swing(CLEAN_SHEET_STEP, fixture) +
      save_points(ranking) * swing(SAVE_STEP, fixture) +
      conceded_points(ranking, fixture) +
      defensive_points(ranking, fixture) +
      bonus_points(ranking)
  end

  def attacking_points(ranking)
    goal_points(ranking) + assist_points(ranking)
  end

  # How far one part of a score is moved by who he is playing. No fixture named
  # means no opinion, which leaves the figure as it stands.
  def swing(step, fixture)
    return 1.0 if fixture.nil?

    step**(AVERAGE_DIFFICULTY - difficulty_of(fixture))
  end

  # Bonus is awarded per match to the three best performers, so it is not in any
  # per-90 rate FPL publishes and has to be worked out from his own totals.
  #
  # Dividing by the minutes he actually played would undo the doubt the rest of
  # the model carries: a rate that grows as the minutes shrink, multiplied by a
  # credibility that shrinks with them, cancels to a fixed share of his bonus
  # however little football it came from. So a short record is read against the
  # five matches of doubt instead, and one bonus point off the bench stays worth
  # about what it was.
  def bonus_points(ranking)
    played = minutes_played(ranking).to_f
    return 0.0 if played.zero?

    record(ranking, "season_bonus") / ([ played, UNPROVEN_MINUTES ].max / FULL_MATCH)
  end

  # Nought before a ball is kicked, and nought for a player with no record, both of
  # which read as no opinion rather than as a slump.
  def form_factor(ranking)
    recent = stat(ranking, "form")
    usual = stat(ranking, "points_per_game")
    return 1.0 if recent.zero? || usual.zero?

    (recent / usual).clamp(1 - form_swing, 1 + form_swing)
  end

  def goal_points(ranking)
    GOAL.fetch(ranking.position, 4) * goals(ranking)
  end

  # Involvements less the goals themselves, never negative however FPL rounds.
  def assist_points(ranking)
    created = [ record(ranking, "expected_goal_involvements_per_90") - goals(ranking), 0.0 ].max
    ASSIST * created
  end

  def clean_sheet_points(ranking)
    CLEAN_SHEET.fetch(ranking.position, 0) * record(ranking, "clean_sheets_per_90")
  end

  # What the goals that go past him cost, which until now was nothing at all: a
  # keeper at a leaky club was charged for the clean sheets he would not keep and
  # given the goals themselves for free.
  #
  # This one takes the fixture itself rather than being multiplied by a swing
  # afterwards, because the points do not follow the goals in a straight line and
  # so cannot be scaled after the fact. See #pairs_of.
  def conceded_points(ranking, fixture)
    penalty = CONCEDED.fetch(ranking.position, 0)
    return 0.0 if penalty.zero?

    -penalty * pairs_of(goals_past_him(ranking, fixture))
  end

  def goals_past_him(ranking, fixture)
    conceded = club_figure(ranking, "expected_goals_conceded_per_90", if_promoted: :the_worst_in_the_league)
    conceded * swing(CONCEDE_STEP, fixture)
  end

  # What a club's players do, where the man himself has no record of doing it.
  #
  # His own figure first, and his club's where he has none: conceding and
  # defending are things a side does together, so a man signed from abroad takes
  # the rate of the defence he has joined rather than no rate at all.
  #
  # A promoted club has no record for anybody, and what to assume of them depends
  # entirely on the measurement. They concede more than anyone, so an unknown
  # defence is charged the worst we know of; left at nought it handed the sides
  # most likely to ship goals the only clean bill in the league. They do not,
  # however, defend any more than the rest. Sunderland and Leeds came up a year
  # ago and make 8.4 defensive actions a game against a league middle of 8.2,
  # while the top of that table is Everton and Newcastle, both long established.
  # So an unknown club is ordinary there, and reaching for the highest figure
  # because it worked for goals would hand players nobody has seen the best rate
  # in the league.
  def club_figure(ranking, type, if_promoted:)
    own = record(ranking, type)
    return own if own.positive?

    club_rates(type)[ranking.team_id] || unknown_club(type, if_promoted)
  end

  # What each club does, taken as the middle of its players' figures so that one
  # man who played only the afternoons it went wrong cannot speak for the side.
  #
  # A club needs a few of them before its own figure beats the assumption. Ipswich
  # had exactly one defender with a conceded rate and the whole squad was
  # inheriting his, which is one man's record wearing a club's name.
  def club_rates(type)
    @club_rates ||= {}
    @club_rates[type] ||= @rankings.group_by(&:team_id).each_with_object({}) do |(team_id, members), rates|
      recorded = members.map { |member| record(member, type) }.select(&:positive?)
      rates[team_id] = middle_of(recorded) if recorded.size >= CLUB_EVIDENCE
    end
  end

  def unknown_club(type, assumption)
    figures = club_rates(type).values
    return 0.0 if figures.empty?

    assumption == :the_worst_in_the_league ? figures.max : middle_of(figures)
  end

  def middle_of(values)
    values.sort[values.size / 2]
  end

  # THE DEFENDING, which is not a rate however FPL publishes it.
  #
  # Two points for clearing a bar in a single match, so what matters is how often
  # he clears it rather than what he averages, and the two are nothing alike. A
  # defender averaging six actions clears ten in about one match in twelve; at
  # nine it is two in five; at eleven it is two in three. Multiplying the average
  # by anything at all prices those three the same way, which is why this is the
  # one part of the scoring table that cannot be read straight off a per-90 rate.
  #
  # Nor can a threshold be scaled by minutes afterwards, because half a match is
  # far less than half a chance of ten actions. So it is worked out over the
  # minutes he actually plays and then divided back out by them: everything here
  # is multiplied by his minutes later, and this way what survives that is the
  # figure calculated here.
  def defensive_points(ranking, fixture)
    bar = DEFENSIVE_ACTIONS[ranking.position]
    share = minutes_share(ranking).to_f
    return 0.0 if bar.nil? || !share.positive?

    actions = club_figure(ranking, "defensive_contribution_per_90", if_promoted: :an_ordinary_side)
    DEFENSIVE_POINTS * chance_of_clearing(actions * share * swing(DEFENSIVE_STEP, fixture), bar) / share
  end

  # How often a count averaging this much comes out at the bar or above, for
  # actions arriving independently through a match.
  def chance_of_clearing(expected, bar)
    return 0.0 unless expected.positive?

    term = Math.exp(-expected)
    below = term
    (1...bar).each do |count|
      term *= expected / count
      below += term
    end
    [ 1 - below, 0.0 ].max
  end

  # How many whole pairs of goals to expect, since only the second of each pair
  # costs anybody a point.
  #
  # Half the goals is the obvious answer and the wrong one, because the lone goal
  # in a one-nil defeat is free and half the time a side conceding two ships them
  # in separate matches. Goals arrive at random and independently, and for
  # arrivals like that the pairs come out as the goals themselves less the chance
  # there is an odd one left over. On a side shipping one and a half a game the
  # difference is a third of a point every week, all of it charged to the clubs
  # that concede most.
  def pairs_of(goals)
    return 0.0 unless goals.positive?

    (goals - (1 - Math.exp(-2 * goals)) / 2) / 2
  end

  # Only ever anything for a keeper, so this needs no position of its own.
  def save_points(ranking)
    record(ranking, "saves_per_90") / SAVES_PER_POINT
  end

  def goals(ranking)
    record(ranking, "expected_goals_per_90")
  end

  # A rate over a handful of minutes is mostly luck, so it is pulled towards
  # nothing until the minutes back it up.
  def credibility(ranking)
    played = minutes_played(ranking).to_f
    played / (played + UNPROVEN_MINUTES)
  end

  # THE THIRD TERM: the games in front of him, each counted for what it is worth
  # to this player. A team playing twice gets two goes at it and a blank week is
  # nought, which is the honest answer.
  #
  # An ordinary fixture is worth 1. A kind one is worth more to a defender than
  # to a forward, and a cruel one costs a goalkeeper less than it costs anybody,
  # because the same afternoon that denies him a clean sheet brings him saves.
  # See CLEAN_SHEET_SWING and the constants around it.
  def games_ahead(ranking)
    @games_ahead ||= {}
    @games_ahead[ranking.player_id] ||= fixtures_for(ranking).sum { |fixture| worth_of(ranking, fixture) }
  end

  # What this fixture is worth against an ordinary one, for this player.
  def worth_of(ranking, fixture)
    ordinary = points_per_90(ranking)
    return 1.0 unless ordinary.positive?

    points_per_90(ranking, fixture) / ordinary
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
    ownership(ranking) * price(ranking)**price_power
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
      perf_factor: perf_factor(ranking, ours, theirs)
    }
  end

  # How far the record moved the market for this player, as it shows in the score.
  # Nil where the market did not lead: a player the crowd cannot see, one nobody
  # owns, or one ruled out and left to his own record.
  def perf_factor(ranking, ours, theirs)
    return nil if ours.nil? || theirs.nil? || ruled_out?(ranking)

    nudge(ours, theirs).round(3)
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
