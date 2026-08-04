# Fantasy Forecast

Forecasts what every Fantasy Premier League player is expected to score, from
FPL's own published data and nothing else.

## The scheduled work

Everything the app does on a schedule is one rake task:

```
bin/rails ff:hourly
```

It runs `Fpl::HourlyPipeline`: detect a season rollover, sync gameweeks,
players, payloads, live scores and last season's histories, then forecast the
coming gameweek and the rest of the season. Every step is idempotent, so running
it twice costs nothing and a missed hour repairs itself on the next one. It
exits non-zero if any step failed, so a scheduler can tell.

**In production it runs from the Heroku Scheduler add-on, configured in the
Heroku dashboard rather than in this repository.** `heroku addons:open scheduler`
to see or change it. Note that `config/recurring.yml` is not what runs it:
production uses the `:async` ActiveJob adapter and no Solid Queue worker, so
that file is never read.

Useful by hand:

```
bin/rails ff:generate       # forecast the next gameweek only
bin/rails ff:accuracy[12]   # mark a finished gameweek's forecast against what happened
bin/rails fpl:new_season    # wipe and re-sync from scratch
```

## Development

```
bin/setup
bin/dev          # web + tailwind watch
bin/rails test
bin/rubocop
```
