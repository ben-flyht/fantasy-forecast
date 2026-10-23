# Accuracy

How well the forecast predicts what players actually score, what has been tried to make
it better, and what data would move it further. Written in October 2026 from a copy of
production after gameweek 7, so every number here rests on six or seven weeks of
football and should be read with that in mind.

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

## What did not help

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

## The season horizon

The rest-of-season forecast still assumes a regular plays every remaining minute.
Gabriel, Calafiori and Rice are forecast for 90 of 90 across 31 games. Recent minutes
pull down the players who have missed time (Isak's projection fell from 161 to 128,
João Pedro's from 158 to 126). They do nothing for an ever-present who will get injured
in February. Seven weeks of data cannot show how much to discount for that: over five
weeks, regulars mostly do play, and discounting them made those forecasts worse. That
needs past seasons.

## What data would help

**1. Past seasons of per-gameweek FPL data.** The
[vaastav/Fantasy-Premier-League](https://github.com/vaastav/Fantasy-Premier-League)
repository has every gameweek from 2016/17, under MIT, keyed by FPL's own ids (re-key
across seasons by `code`). It turns seven gameweeks of evidence into a hundred or more,
which every finding above needs. It is also the only honest way to learn how much of a
season regulars miss, by position, price and age. Its `xP` column leaks post-match
information and must be shifted or ignored. It now updates three times a season, so it
is history, not a live feed. This comes first.

**2. Bookmaker odds.** [football-data.co.uk](https://www.football-data.co.uk/englandm.php)
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
