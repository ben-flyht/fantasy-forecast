# Comparisons

`/compare` answers the question a manager types into a search box: him or him? And,
since August 2026, the bigger question he usually holds: these two, or those two?

This is the reasoning behind that page, and what is still missing from it.

## What a comparison is

Two sides. A side is one player, or the two or three you would buy in one move.

```
/compare/viktor-gyokeres-25-vs-erling-haaland-411
/compare/viktor-gyokeres-25-and-igor-thiago-nascimento-rodrigues-106-vs-joao-pedro-junqueira-de-jesus-165-and-erling-haaland-411
```

`-vs-` separates the sides, `-and-` joins the players on one. There is no limit on how
many a side holds: a move is usually one or two, but the page adds up however many you
give it, so nothing about the arithmetic caps the question.

Every ordering of the same argument is one page. Players sort within a side by FPL's
own id, then the sides sort by the lowest id on each, and any other spelling is 301'd
to that one. A side of one comes out byte-identical to the address it had before groups
existed, so nothing that was crawled or shared has moved.

**Why groups at all.** A manager with two free transfers is not choosing between two
players. He was opening two pair pages and doing the addition himself, and that
addition is the arithmetic this site exists to do for him.

## Adding two players up honestly

Summing is easy. The rules below are what stop the sum lying.

**A side is unforecast when anybody on it is.** Not nought, and not the rest of the
side without him. A pair that quietly drops a man and still shows a number is worse
than a pair with no number at all. `HeadToHead::Side#forecast?`

**The gap two sides must clear grows with the side.** `HeadToHead::CLOSE` is 0.25 of a
point a week, the smallest difference we claim to see between two players. Two players
carry two players' worth of error, and independent errors add in quadrature, so the
threshold is `CLOSE * sqrt(size)`: two pairs have to be about a third of a point apart,
not a quarter. `HeadToHead#close_enough`

**Nothing on a side of two is graded or ranked.** A grade is a mark out of ten for one
player over one week, and two players' points added together would earn any pair an A.
Each man keeps his own grade on his own card. A side of one still answers for its
player, so the page and the card written for a pair did not have to change.

**The table knows what adds up.** `ComparisonStats::Stat#aggregate`:

| Rule | Applies to | Why |
|---|---|---|
| `:sum` (default) | totals, and anything earned per gameweek: points, minutes, bonus, form, points per game, expected points | you own both, so you collect both |
| `:per_90_mean` | every `_per_90` rate, weighted by `season_minutes` or `last_season_minutes` | two rates are not one rate when added; this is what the side did between them |
| `:each` | ownership, set-piece order | a share of the game's managers and a place in a penalty queue belong to one man, so each is written out ("1st and 3rd") and the row favours nobody |

A `:sum` with a missing reading is blank, for the same reason a side with an unforecast
player is.

**The page says what the cards cannot.** Where the sides hold different numbers of
players, that this was never a like-for-like question: three players score more than
two for that reason alone (`ComparisonsHelper#uneven_note`). The price difference is
left to the players' own prices on their cards; a line spelling it out ("Saka and
Haaland cost £4.0m more") was tried and removed as noise.

## Building and changing an argument

The builder is one component, used two ways. Each side has a box you can always type
into and the players you have chosen stand as chips above it; a chip carries the
player's `to_param`, and the chips in the DOM are the state, so nothing is held in step
with them (`comparison_builder_controller.js`).

On the hub it starts empty and a button takes you to the address it has assembled. On
a comparison it starts as that comparison's own sides, and there is no button: adding,
removing or replacing a player `Turbo.visit`s straight to the page for the sides you
have now, so the address and the answer follow your edits. A side always keeps at
least one player there, because a side of nobody is not a question — the last chip on a
live side will not remove until something stands beside it. There is no cap on how many
a side holds.

## What people ask, and what we offer back

Every comparison that reaches the page is counted against its canonical slug
(`ComparisonRequest.record`, called from `ComparisonsController#show`). The picture a
link turns into is not — that is a crawler, not a manager — so only the HTML view is
counted.

`MostRequestedComparisons` reads the top of that tally back: onto the hub as "Most
compared this week", and into the sitemap alongside the forecast-picked pairs, the
asked-for ones leading. **Pairs only.** A group is counted the same as a pair, because
knowing a group was asked is worth having, but the hub is a page to scan and a sitemap
is an index of pages worth crawling, and neither is served by two-a-side groups. A
manager builds the group he has in mind; we offer back the straight choices.

## Indexing

Pairs are a deliberate crawlable inventory. There are about 160,000 of them, they are
linked internally by `PopularComparisons` (the hub, the sitemap) and
`RelatedComparisons` (the foot of every comparison and player page), and people search
for them by name.

Groups are combinatorially enormous and nobody searches for one, so a comparison with
more than one player on a side is `noindex, follow` and stays out of the sitemap.
Followed rather than ignored, because the players and the pairs beside them are worth
reaching. This is why the layout's robots tag became `ApplicationHelper#meta_robots`,
which a page can answer for itself.

## Where the pieces live

| File | What it holds |
|---|---|
| `app/models/comparison.rb` | the sides an address names, the canonical spelling, what is not a question |
| `app/services/head_to_head.rb` | the sides scored, the pick, the margin, the threshold |
| `app/services/comparison_stats.rb` | the working underneath, and the aggregation rules |
| `app/services/popular_comparisons.rb` | the pairs worth putting on a page (pairs only) |
| `app/services/related_comparisons.rb` | the next argument (pairs only) |
| `app/models/comparison_request.rb` | the tally, one row a canonical slug |
| `app/services/most_requested_comparisons.rb` | the asked-for pairs read back for the hub and sitemap (pairs only) |
| `app/views/comparisons/show.html.erb` | the answer, with the builder filled in beneath it |
| `app/views/comparisons/_builder.html.erb` + `comparison_builder_controller.js` | building an argument on the hub, or changing one on its own page |
| `app/views/cards/comparison.svg.erb` | the picture a pair turns into in a group chat |

---

# Not done

In the order I would take them.

## 1. A share card for a group

**The gap.** `cards/comparison.svg.erb` is a diagonal split into two team-coloured
halves with one enormous surname on each. That design does not stretch to three names a
side. So a group asked for as `.png` is 404'd today
(`ComparisonsController#send_comparison_card`) and a group page sets no `og:image`,
which means it previews as the site icon.

**The shape to borrow** is the squad card, not the current comparison card:
`app/views/cards/squad.svg.erb` already stacks fifteen names in two columns with a club
and a price under each, and one big number down the left. A group card is a column per
side: the side's total as the headline, the names beneath it, the team colour as an
accent on each name rather than half the canvas.

A side has no limit now, so the card has to choose its own: three names read well in a
column, and past that a "+2 more" line beats a wall of them. Remember `ShareCard::SQUARE`
exists for cards that cannot be a letterbox, and that `meta_image_height` has to be told
about it.

This is the smallest of the five and the feature is half-delivered without it.

## 2. "a or b or c": three-way alternatives

Deliberately parked. The original ask was two things, and only the first was built:
`x+y` vs `a+b` is done, `a` or `b` or `c` is not.

Worth deciding whether it is a real need first. A three-way is genuinely a different
page: `pick`/`runner_up` assume two sides, the two-column layout assumes two, and
`RelatedComparisons` already offers a way to walk from one pair to the next. It may be
that two sides is the whole question.

## 3. Credit the cheaper side with what its spare money buys

Today the page leaves the price difference to the two sides' own prices and says
nothing about it (the line that spelled it out was removed as noise). The honest next
step is to price the gap: £1.5m spare is worth whatever upgrading the worst player in a
typical squad by £1.5m is worth. That turns the page from "which scores more" into a
proper transfer answer, and it is the single thing that would make bundle comparisons
better than doing the sum yourself.

Needs a defensible number for "what a spare million buys", probably read from the
rankings rather than invented.

## 4. Cards nobody can see

Four share cards exist. Three of them are never shown on the site: only the squad card
appears on a page (`home/show.html.erb`), and it is also the only one with a line of
copy selling it ("That picture is what lands in the chat").

Two specific gaps:

- **The captain page has no card of its own.** It borrows the pick's player card, so a
  shared captain link previews as a player rather than as an answer to the one decision
  every manager makes every week. That is the highest-intent page on the site.
- **The `/compare` hub sets no `meta_image` at all**, so it falls back to `/icon.png`.

Separately, whether to render cards on the pages themselves was asked and answered "not
now". Revisit once the group card exists.

## 5. Copy that still says "two"

Mostly cleaned up, but the hub (`comparisons/index.html.erb`) still describes
comparisons as answering "two players, the points we expect from each" in its FAQ and
its "How a comparison is answered" section, and quotes the 0.25 threshold as a flat
number. True for pairs, no longer the whole story. Low stakes, worth a pass when the
hub is next touched.
