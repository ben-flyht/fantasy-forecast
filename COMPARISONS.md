# Comparisons

`/compare` answers the question a manager types into a search box: him or him? And,
since August 2026, the bigger question he usually holds: these two, or those two?

This is the reasoning behind that page, and what is still missing from it.

## What a comparison is

Two sides. A side is one player, or the two or three you would buy in one move.

```
/compare/gyokeres-25-vs-haaland-411
/compare/gyokeres-25-and-thiago-106-vs-j.pedro-165-and-haaland-411
```

`-vs-` separates the sides, `-and-` joins the players on one. A player is spelled by his
short name and id (`Player#comparison_param`), shorter than his own page's full-name
address, since a full name on both sides of a trade runs the URL long — a 15-a-side is
700-odd characters as it is. `from_param` reads the id either way, so an older
first-and-surname comparison link still resolves and is 301'd to the short spelling.

A side holds up to fifteen (`Matchup::MAX_PER_SIDE`) — a squad's worth, far more than
any real move. Not a limit on the question, a rail against an address hand-typed to name
half the league, counted from the raw string before a single player is looked up so a
pathological request is refused rather than run.

Players sort within a side by FPL's own id, so who is on a side has one spelling. A
one-against-one is symmetric — Salah or Palmer is Palmer or Salah — so its two sides are
ordered by id as well, and any other spelling is 301'd to it.

A trade keeps its sides in the order they were written. It is a tool you edit in place,
and columns that swapped left-for-right as you added or dropped a player would be
unreadable, so the two orderings of a trade's *sides* are two addresses. Everything else
is still tidied to one: reorder the players within a side and you are 301'd to the
spelling that sorts them. Groups are `noindex` regardless (see below), so the pair of
side-orderings costs nothing a crawler would spend.

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

**The table is the record, not the forecast.** The cards above say what we expect;
`ComparisonStats` is what has actually happened — per-90 rates, season totals, current
form, and FPL's own indices (goals, xG, saves, ICT, threat, and the rest), in one
group, each row labelled with what it is (a total plainly, a rate as "per 90") so a
rate is never read as a total. Before a ball is kicked this season it reads last
season's figures where it has them, then this season's once they exist.

**A side is its players summed — everything, rates included.** Not a weighted mean: for
a trade a manager wants the side's combined output a game (two attackers threatening
1.0 xG a game between them), not an average that describes no player who exists. A sum
is only a sum when we have all of it, so a side missing one man's figure is blank rather
than the rest of the side without him, and a row nobody has — or that is nought on both
sides, like a forward's saves — is not drawn.

**The page still says what the cards cannot.** Where the sides hold different numbers of
players, that this was never a like-for-like question: three players score more than
two for that reason alone (`ComparisonsHelper#uneven_note`). The price difference is
left to the players' own prices on their cards; a line spelling it out ("Saka and
Haaland cost £4.0m more") was tried and removed as noise.

## Building and changing an argument

The builder is one component, used two ways. Each side has a box you can always type
into — a proper combobox, so a screen reader announces the option the arrow keys land on
— and the players you have chosen stand as chips above it; a chip carries the player's
`comparison_param`, and the chips in the DOM are the state, so nothing is held in step
with them (`comparison_builder_controller.js`).

On the hub it starts empty. On a comparison it starts as that comparison's own sides,
its cards doubling as the chips, each with a cross to drop it. Either way there is no
button: the moment both sides hold a player, adding, removing or replacing one
`Turbo.visit`s straight to the page for the sides you have now, so the address and the
answer follow your edits. A half-built side keeps the address in step through
`history.replaceState`, so it can be shared or reloaded and picked back up. A side of
nobody is not a page, so the last chip on a live side empties to its box and waits for a
replacement rather than leaving. The page is `turbo-cache no-cache`, so back and forward
re-render rather than restore a snapshot of a moment that has passed.

## What people ask, and what we offer back

Every comparison that reaches the page is counted, once a session, against its canonical
slug for the gameweek (`Comparison.record`, called from `ComparisonsController#show`).
Once a session, because a manager editing his way to a comparison, or coming back to it,
is one person asking, not the fifty hits the live editor would otherwise record (the
slugs he has counted are held as short digests in the cookie). Per gameweek, so a fresh
set of arguments surfaces each week rather than an all-time list. The picture a link
turns into is not counted — that is a crawler, not a manager.

`MostRequestedComparisons` reads the top of that week's tally back: onto the hub as "Most
compared this week", and into the sitemap alongside the forecast-picked pairs. When the
week's tally is thin it is topped up with the forecast's closest highly-ranked pairs, so
the hub always offers something worth reading. **Pairs only.** A group is counted the
same as a pair — knowing a group was asked is worth having — but the hub is a page to
scan and the sitemap an index worth crawling, and neither is served by two-a-side groups;
a `pair` flag on each row lets both read the top pairs without ever resolving (and so
paying for) a group slug someone may have crafted to be expensive.

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
| `app/models/matchup.rb` | the sides an address names, the canonical spelling, what is not a question |
| `app/models/comparison.rb` | the per-gameweek tally of comparisons asked for (the `comparisons` table) |
| `app/services/head_to_head.rb` | the sides scored, the pick, the margin, the threshold |
| `app/services/comparison_stats.rb` | the underlying record read across two sides, summed and labelled |
| `app/services/popular_comparisons.rb` | the pairs worth putting on a page (pairs only) |
| `app/services/related_comparisons.rb` | the next argument (pairs only) |
| `app/services/most_requested_comparisons.rb` | the week's asked-for pairs, topped up with close ones, for the hub and sitemap (pairs only) |
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
