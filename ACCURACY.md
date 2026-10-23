# Accuracy

How well the forecast predicts what players actually score, what has been tried to make
it better, and what data would move it further. Written in October 2026 from a copy of
production after gameweek 7, so the first half of it rests on six or seven weeks of
football. The second half, [Two past seasons](#two-past-seasons), replays the model over
every gameweek of 2024/25 and 2025/26 and settles what those weeks could not.

## How it is measured

**The deadline snapshot.** Snapshot statistics are filed against the *current*
gameweek and refreshed until the next deadline. The readings filed against gameweek
N−1 are therefore what was known at gameweek N's deadline, and the readings filed
against N itself are taken after N's football. Anything that marks or replays gameweek
N reads N−1's snapshot. FPL's fitness flag for N is in N−1's element payload as
`chance_of_playing_next_round`. Gameweek 1 has no earlier snapshot, so it cannot be
replayed or given fair baselines.

**Replay.** Forecasts can be rebuilt from that snapshot and compared with the stored
ones. Rebuilt forecasts match the stored ones exactly for gameweeks 6–8, and for about
90% of players in gameweeks 2–5, where FPL later revised some of its figures. That makes
it safe to try a change against the evidence the live model actually had.

**Scores.** Each gameweek and position is scored, then averaged:

- *Ranking*: Spearman correlation with actual points, over players who matter (owned
  by 1% or more, or forecast 2+ points a week). Correlation over every player is
  inflated by hundreds of non-players correctly ranked last.
- *Capture*: of the points the best 10 in a position scored, how many our top 10 got.
  This is `ForecastAccuracy`'s headline.
- *Error*: root mean square error, and bias, in points.
- *Top 11*: average points of our 11 highest forecasts regardless of position, which
  is what cross-position choices such as the squad optimiser lean on.

The upcoming horizon is scored the same way against points summed over its window,
using 3-week windows from gameweeks 2–5 and 5-week windows from gameweeks 2–3.

**History backtest.** `rake ff:fetch_history` downloads past seasons from
[vaastav/Fantasy-Premier-League](https://github.com/vaastav/Fantasy-Premier-League) and
match odds from [football-data.co.uk](https://www.football-data.co.uk/englandm.php), and
`rake ff:backtest_history` replays `ExpectedPoints` over them (about three minutes).
For each gameweek N, `History::Season` rebuilds what the model reads at N's deadline
from gameweeks before N only: season minutes, per-90 xG, xA, xGC, saves and defensive
contribution, bonus, form (points per match over the 30 days before the deadline),
points per game, last season's figures matched by player `code`, and recent minutes.
Price, ownership and the week's transfers come from gameweek N's own row, which FPL
records at the deadline. The model is called once per position, as `Forecaster` does,
with the same horizon settings as the live forecasters. Where it departs from live:

- Nobody is flagged. The data has no fitness flags, so every player is treated as fit.
  This inflates error and bias, mostly at the 1-week horizon, where live forecasts drop
  injured players.
- The manager count is the sum of every player's `selected` divided by 15, which gives
  10.8 million at gameweek 2 of 2025/26 and 12.8 million by gameweek 20.
- FDR and the fixture list are as they stood at the end of the season, not as they
  were at each deadline, so postponements are already known.
- The 2024/25 replay has no defensive contribution, which FPL introduced in 2025/26.
- The rebuilt inputs could not be compared with production's stored snapshots for
  this season, because the session that wrote this could not read the production copy.

Scores are the same four as above, with two changes. The relevant set comes from the
production model's forecast, so every variant is marked on the same players. Error is in
points over the whole window. The 1-week horizon covers all 38 gameweeks, the 5-week
horizon every gameweek with five left (34), and the season horizon every gameweek with
ten or more left (29). Each "likelihood better" is the share of 2,000 bootstrap resamples
of gameweeks in which the change wins. Resampling uses blocks of 5 and 10 gameweeks on
the longer horizons, because their windows overlap.

## Where we stand (gameweeks 2–7, stored forecasts)

| | Ours | FPL expected points | Most-owned |
|---|---|---|---|
| Ranking | **0.57** | 0.46 | 0.28 |
| Capture | **55%** | 53% | 54% |
| Average error per player-week (points) | **1.15** | 1.26 | – |

We rank players better than FPL's own expected points in defence, midfield and attack.
Goalkeepers are even. Blending FPL's figure or ownership into ours adds nothing: a
regression fitted per position puts almost all of its weight on our forecast.

## What changed

**Calibration** (`SCORING_CALIBRATION`, model 8). Forecasts ran high at the top: players
forecast 5.5–7 points averaged 4.5, and those forecast over 7 averaged 5.9. What a
player earns beyond his appearance points is scaled by 0.8. Ranking within a position is
unchanged, and error on relevant players falls from 2.85 to 2.81.

**Recent minutes** (model 9). Minutes are the average of the season-long share and the
share of the last three gameweeks' football he played. The season-long share took about
five weeks to believe a new regular: Timber started every match from gameweek 3 and
was forecast 35, 58 and then 72 minutes. It was just as slow to notice a dropped one.

| Horizon | Ranking before | Ranking after | Likelihood the gain is real | Bias before | Bias after |
|---|---|---|---|---|---|
| 1 week | 0.568 | 0.575 | 99% | +0.05 | −0.12 |
| 3 weeks | 0.610 | 0.623 | 100% | +0.50 | −0.01 |
| 5 weeks | 0.617 | 0.632 | 100% | +1.27 | +0.37 |

**Return dates on the upcoming horizon.** The upcoming forecast multiplied all five
weeks by this week's fitness flag, so a player out for one match scored nothing for the
whole window. Doku, due back the day after the gameweek 3 deadline, was forecast 0 and
scored 19. It now reads return dates through `Availability`, as the season horizon
already did. Of the 31 forecasts it changes by more than half a point, 22 move closer to
what happened. The aggregate ranking is 0.003 lower, almost all from one doubtful player
given near-full credit who then scored nothing.

**Opponent form** (`OpponentForm`, model 10). FDR is a fixed, preseason view of each
club. Fixture difficulty now also reads how the opponent has actually played this
season: the expected goals it has conceded and created per match, from finished
gameweeks only, pulled towards the league average by four matches' worth of it. That
is turned into a difficulty on FDR's scale and given a quarter of the say. The rest
stays with FDR. Attack reads the opponent's conceding and moves goals and assists.
Defence reads its creating and moves clean sheets, saves, goals conceded and
defensive contributions. The idea came from Let's Talk FPL, which grades fixtures on
opponents' xG conceded per game.

The backtest rebuilds the form from matches before each forecast round, including for
the five-week horizon:

| Season | Horizon | Ranking | Capture | Top 11 | Likelihood ranking is better |
|---|---|---|---|---|---|
| 2024/25 | 1 week | 0.537 → 0.541 | 56.3% → 56.6% | 5.81 → 5.84 | 100% |
| 2024/25 | 5 weeks | 0.584 → 0.585 | 72.3% → 72.4% | 25.0 → 25.1 | 91% |
| 2025/26 | 1 week | 0.498 → 0.500 | 54.3% → 54.4% | 4.98 → 4.95 | 93% |
| 2025/26 | 5 weeks | 0.530 → 0.531 | 71.2% → 71.4% | 21.5 → 21.7 (99%) | 76% |
| 2026/27, gameweeks 2–6 | 1 week | 0.498 → 0.499 | 54.0% → 54.7% (88%) | 5.29 → 5.42 (88%) | 70% |

The weight was swept. More of the say helps 2024/25 and hurts the two seasons after it,
so a quarter is the most that improves every season:

| Weight | 2024/25 ranking, 1 week | 2025/26 ranking, 1 week | 2025/26 ranking, 5 weeks | 2026/27 ranking, 1 week |
|---|---|---|---|---|
| 0.25 | 0.541 | 0.500 | 0.531 | 0.499 |
| 0.5 | 0.542 | 0.499 | 0.530 | 0.497 |
| 0.75 | 0.541 | 0.496 | 0.527 | 0.493 |
| 1.0 | 0.538 | 0.494 | 0.525 | 0.486 |

Full weight is close to the earlier "ratings from this season's xG instead of FDR",
which lost 0.011.

## What did not help

From the two-season backtest:

| Idea | Result |
|---|---|
| Bookmaker odds in place of FDR (1 week) | Ranking 0.537 → 0.528 and 0.498 → 0.489 (better in 5% and 4% of resamples), RMSE worse in both seasons |
| Odds with attack and defence rated apart | Ranking 0.537 → 0.530 and 0.498 → 0.488, RMSE worse |
| `SCORING_CALIBRATION` 0.7 or 0.9 instead of 0.8 | Ranking moves by under 0.001. 0.7 lowers weekly RMSE (2.96 → 2.93), but that is against flag-free bias, so it would overcorrect live. Kept at 0.8 |
| `RECENT_GAMEWEEKS` 2 instead of 3 | Weekly ranking +0.005 in both seasons, capture −0.004 then +0.001, season ranking −0.002. Kept at 3 |
| `RECENT_GAMEWEEKS` 6 instead of 3 | Season ranking +0.005, RMSE −0.3, weekly ranking −0.017. Kept at 3 |
| Dropping recent minutes entirely | Weekly ranking 0.518 → 0.468: recent minutes are confirmed |
| Minutes discount by price band | Bands differ by 4 points at most. No better than one outfield figure |
| Softening FDR's swing by half | 2024/25 ranking +0.006, but 2025/26 capture −1.0 point. Mixed. Worth a proper look at the fixture steps |

From gameweeks 2–7:

| Idea | Result |
|---|---|
| Retuning any of the 21 existing parameters | Nothing beats noise |
| Letting a player's record argue further against the market (wider nudge band) | Defender ranking 0.427 → 0.378 |
| Dropping the transfer-traffic factor | Capture falls 2.1 points, the only clear loss in the sweep |
| Team attack and defence ratings from this season's xG instead of FDR | Ranking −0.011, likely a real loss |
| Home advantage | Home players scored 3.23 against 3.35 away, despite higher forecasts. Nothing to add |
| Recent xG form over the last four gameweeks | +0.001, worse top-11 picks |
| A different calibration for each position | +0.001, worse top-11 picks over 3 weeks. Overfitting |
| Removing points-form | Better weekly (+0.004), worse over 3 weeks (−0.006) |
| Discounting minutes by last season's share of the season played | 5-week bias −1.97, ranking −0.005 |
| Penalty and set-piece duty | No signal left over: FPL's xG already counts penalties |

From Let's Talk FPL's habits, tested on the two-season backtest and 2026/27 gameweeks 2–6:

| Idea | Result |
|---|---|
| Weighting this season's defensive contribution rate more than last season's | 2026/27 ranking 0.498 → 0.494 with this season alone. Kept as blended |
| Defensive contribution from how often he cleared the bar, not his average | 2026/27 ranking −0.002, RMSE worse |
| Fewer minutes for clubs in Europe (×0.95 or ×0.90) | Weekly ranking +0.001, but 5-week ranking −0.001 to −0.004 in 2025/26 and capture mixed |
| Regressing per-90 xG above 0.5 and xA above 0.3 by half | Top-11 picks worse in both seasons (2% and 1% of resamples better) |
| Halving the form swing | Ranking +0.004 in 2025/26 and RMSE better everywhere, but 2024/25 capture worse (0% and 3% of resamples better). Not taken up yet |

## Two past seasons

The production model, replayed as above. Each figure is a mean across gameweeks ± 95%.

| Season | Horizon | Gameweeks | Ranking | Capture | RMSE | Bias | Top 11 |
|---|---|---|---|---|---|---|---|
| 2024/25 | 1 week | 38 | 0.541 ± 0.023 | 56% ± 2 | 2.88 ± 0.09 | +0.34 ± 0.06 | 5.8 ± 0.6 |
| 2024/25 | 5 weeks | 34 | 0.585 ± 0.017 | 73% ± 2 | 8.35 ± 0.17 | +2.01 ± 0.16 | 25.1 ± 1.5 |
| 2024/25 | Rest of season | 29 | 0.610 ± 0.018 | 80% ± 1 | 28.2 ± 3.6 | −1.1 ± 0.6 | 102 ± 14 |
| 2025/26 | 1 week | 38 | 0.499 ± 0.025 | 54% ± 3 | 3.01 ± 0.07 | +0.23 ± 0.06 | 4.9 ± 0.4 |
| 2025/26 | 5 weeks | 34 | 0.531 ± 0.014 | 71% ± 1 | 8.74 ± 0.16 | +1.53 ± 0.20 | 21.7 ± 1.0 |
| 2025/26 | Rest of season | 29 | 0.535 ± 0.016 | 78% ± 1 | 28.9 ± 3.8 | −2.8 ± 0.7 | 95 ± 12 |

The weekly ranking of 0.50–0.54 over whole seasons sits below the 0.57 measured on this
season's first seven weeks. Some of that gap is the missing fitness flags and some is
the early weeks being easier. The season figures include the new minutes discount.

### How much of a season regulars miss

For every forecast, the minutes the model projected (its minutes share times the
team's remaining fixtures) are compared with the minutes played. The sample is players
who played the week before, a stand-in for "fit and unflagged", because the live model
already handles flagged players through `Availability`.

| Season | Outfield under £5.5m | £5.5–7.4m | £7.5m and up | All outfield | Goalkeepers |
|---|---|---|---|---|---|
| 2024/25 | 79% | 77% | 75% | 78% | 90% |
| 2025/26 | 79% | 78% | 76% | 78% | 87% |

Over the rest of a season, an outfield player plays 78% of the minutes the model
projects for him. That held in both seasons, and price makes almost no difference. The
cheapest players keep slightly more, because their projection is already lower.
Goalkeepers keep about 88%. By position, outfielders move between seasons
(forwards 74% then 83%, midfielders 80% then 76%), which looks like noise rather than
something to fit. Projected full-time regulars (share 0.95 and up) keep only 74%:
injuries, suspensions, rotation, substitutions and January departures all count.

Fitted on one season and tested on the other, a flat discount of this size:

| Tested on | Season RMSE | Season bias | Ranking, capture |
|---|---|---|---|
| 2025/26 (fitted on 2024/25) | 34.8 → 28.9 (100%) | +12.9 → −2.2 | unchanged |
| 2024/25 (fitted on 2025/26) | 34.4 → 28.3 (100%) | +13.9 → −0.6 | unchanged |

A linear version, where low-share players keep more than their projection and
regulars less, ranked better in one season and worse in the other. It was not adopted.

## The season horizon

The rest-of-season forecast assumed a regular plays every remaining minute: Haaland was
projected for about 295 points. It now multiplies every player's season fitness by
`SeasonForecast::MINUTES_KEPT`, 0.78 for outfielders and 0.88 for goalkeepers, pooled
from both seasons. This is on top of `Availability` for flagged players. Ranking within a
position does not move. The totals stop running 13 points high per relevant player.

The same discount would help the 5-week horizon (RMSE 8.42 → 7.91 and 8.77 → 8.42 out
of sample). It is not applied there yet: over five weeks, live fitness flags already
close part of the gap that this flag-free replay sees.

## What data would help

**1. Past seasons of per-gameweek FPL data. Done:** see [Two past seasons](#two-past-seasons). The
[vaastav/Fantasy-Premier-League](https://github.com/vaastav/Fantasy-Premier-League)
repository has every gameweek from 2016/17, under MIT, keyed by FPL's own ids (re-key
across seasons by `code`). It turns seven gameweeks of evidence into a hundred or more,
which every finding above needs. It is also the only honest way to learn how much of a
season regulars miss, by position, price and age. Its `xP` column leaks post-match
information and must be shifted or ignored. It now updates three times a season, so it
is history, not a live feed. This comes first.

**2. Bookmaker odds. Tested, and not worth a sync.** Over two full seasons, odds-implied
team goals (pre-match `AvgH/AvgD/AvgA` and `Avg>2.5/Avg<2.5`, fitted to two Poisson
means) predict a side's goals better than FDR (Spearman 0.345 against 0.257 in
2024/25, 0.298 against 0.236 in 2025/26), and clean sheets slightly better (0.23 against
0.21, 0.25 against 0.20). Put in the model in place of FDR, scaled to FDR's spread, they
rank players worse in both seasons (see above). Only the 1-week horizon is a fair test:
pre-match odds for fixtures weeks ahead are not published at the deadline, so odds on
the longer horizons carry future team news. The original note follows.

[football-data.co.uk](https://www.football-data.co.uk/englandm.php)
publishes match odds and over/under 2.5 for every Premier League match since 1993, free,
updated twice a week, including this season. Turned into implied goals per team, odds
predicted a side's goals about twice as well as FDR over this season's 70 matches
(Spearman 0.27 against 0.13, and 0.28 against 0.19 for xG). FDR was better for clean
sheets (0.26 against 0.19). Used in place of FDR in the replay, forward ranking improves
(0.694 → 0.710), defender ranking falls, and overall it is a wash. Promising for
attackers and unproven overall. It should be judged on last season's 380 matches, which
the same site has, alongside source 1. Player markets such as anytime goalscorer need a
paid feed. [The Odds API](https://the-odds-api.com/) lists them for the Premier League
from US bookmakers only, and how complete that coverage is has not been checked.

**3. Fixture congestion.** European and cup fixture dates, for example from
[football-data.org](https://www.football-data.org/coverage), whose free tier covers the
Premier League and Champions League. A rotation signal the minutes model cannot see.

**Not worth it, or not available:**

- Confirmed lineups arrive about an hour before kickoff, which is after the FPL deadline.
- Predicted lineups are paid and have no clear licence.
- FBref lost its Opta advanced stats in January 2026.
- FotMob's terms forbid bulk retrieval.
- Understat would duplicate the Opta xG FPL already publishes.
