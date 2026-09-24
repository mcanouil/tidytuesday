// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per surveyed cafe: what a small cappuccino costs there and what the
// barista serving it earns in an hour, both converted to pounds.
// Source: data/cafe.csv (TidyTuesday 2026-09-08).
#let cafes = csv("data/cafe.csv", row-type: dictionary)

// The published index, one row per country, kept only to check that the figure
// reproduces it. Everything drawn is recomputed from the cafes.
// Source: data/cappuccino_index.csv (TidyTuesday 2026-09-08).
#let published = csv("data/cappuccino_index.csv", row-type: dictionary)

#let comma = format-comma()

// Below five cafes an interval is wider than the cup and its width is set by one
// or two prices. Those countries carry no interval, so the figure leaves them
// out and says so instead.
#let min-sample = 5

#let priced = cafes.map(row => (
  country: row.country,
  city: row.city,
  price: float(row.price_gbp),
  wage: float(row.hourly_wage_gbp),
))

// The index is a ratio of sums, not a mean of ratios: total spend over total
// earnings, in minutes. Its uncertainty follows the ratio estimator, whose
// variance combines the two spreads and their covariance. The normal interval
// is clipped at zero, because no cappuccino is paid for in negative minutes.
#let index-for(rows) = {
  let n = rows.len()
  let sum-price = rows.map(r => r.price).sum()
  let sum-wage = rows.map(r => r.wage).sum()
  let index = 60 * sum-price / sum-wage
  let interval = none
  if n >= min-sample {
    let mean-price = sum-price / n
    let mean-wage = sum-wage / n
    let var-price = rows.map(r => calc.pow(r.price - mean-price, 2)).sum() / (n - 1)
    let var-wage = rows.map(r => calc.pow(r.wage - mean-wage, 2)).sum() / (n - 1)
    let covariance = rows.map(r => (r.price - mean-price) * (r.wage - mean-wage)).sum() / (n - 1)
    let relative = (
      var-price / calc.pow(mean-price, 2)
        + var-wage / calc.pow(mean-wage, 2)
        - 2 * covariance / (mean-price * mean-wage)
    ) / n
    let se = index * calc.sqrt(calc.max(relative, 0))
    interval = (lo: calc.max(index - 1.96 * se, 0), hi: index + 1.96 * se)
  }
  (n: n, index: index, interval: interval)
}

#let countries = {
  priced
    .map(r => r.country)
    .dedup()
    .map(name => (
      country: name,
      ..index-for(priced.filter(r => r.country == name)),
    ))
    .sorted(key: c => c.index)
}

#let country-at(name) = {
  let hit = countries.find(c => c.country == name)
  assert(hit != none, message: "no cafes left for " + name)
  hit
}

// The recomputed index has to match the published one, or the figure is telling
// a story about a different number.
#for row in published {
  let mine = country-at(row.country)
  assert(
    calc.abs(mine.index - float(row.index)) < 0.001 and mine.n == int(row.n),
    message: "recomputed index no longer matches the published one for " + row.country,
  )
}

#let solo = countries.filter(c => c.n == 1)
#let thin = countries.filter(c => c.n < min-sample)
#let drawn = countries.filter(c => c.interval != none)
#let fastest = countries.first()
#let runner-up = countries.at(1)

// The claim the figure is built on: the country in second place cannot be told
// from the country in first.
#assert(
  runner-up.interval != none and runner-up.interval.lo < fastest.index,
  message: "second place no longer reaches below the fastest index",
)
#assert(
  fastest.interval != none,
  message: "the fastest country no longer carries an interval to draw",
)

// The clock. One turn is an hour, zero is at twelve, and the hand runs
// clockwise. The radius shrinks with the sweep, so the swirl starts at the rim
// and winds inwards: the first hour, where 38 of the 46 countries sit, gets the
// longest sweep and lands against the minute scale on the rim, and the thin
// tail of slow countries is what gets squeezed into the middle instead.
#let turn = 60
#let disc = 1.02
#let bezel = 1.2
#let start-radius = disc - 0.06
#let end-radius = 0.3

// The swirl stops just past the furthest interval drawn, and the gap between
// turns is whatever is left over. Fewer turns means a wider gap, which is what
// keeps the arcs apart.
#let spiral-end = drawn.last().interval.hi + 6
#let ring = (start-radius - end-radius) * turn / spiral-end

// The cup keeps a margin inside the panel, so the rim never runs under the
// subtitle or the caption.
#let panel-half-y = bezel + 0.14

#let radius-at(minutes) = start-radius - ring * (minutes / turn)
#let on-ray(minutes, r) = {
  let angle = 2 * calc.pi * minutes / turn
  (x: r * calc.sin(angle), y: r * calc.cos(angle))
}
#let point-at(minutes) = on-ray(minutes, radius-at(minutes))

#assert(
  radius-at(0) < disc and radius-at(spiral-end) > 0.15,
  message: "the swirl no longer fits between the rim and the middle of the cup",
)

#let arc(from, to, steps: 24) = {
  range(steps + 1).map(i => point-at(from + (to - from) * i / steps))
}
#let circle-at(r, steps: 180) = {
  range(steps + 1).map(i => {
    let angle = 2 * calc.pi * i / steps
    (x: r * calc.sin(angle), y: r * calc.cos(angle))
  })
}

// The countries the figure names: the two the title compares, the largest
// sample, the two ends of the range, and one from each half of the dial so the
// two label columns come out even. Everything else is a mark without a name.
#let named = (
  "Australia",
  "Italy",
  "UK",
  "France",
  "Greece",
  "India",
)

#assert(
  runner-up.interval.hi > fastest.index,
  message: "second place no longer straddles the fastest index",
)
#for name in named {
  assert(
    country-at(name).interval != none,
    message: name + " is named but no longer carries an interval to draw",
  )
}

// Only the named countries carry an arc. Drawn for all 46 they overlap into one
// continuous band that no reader can take apart; drawn for six they stay
// separate, and because the six span the whole range of sample sizes they show
// what the band could not: the arc is short where the survey reached many cafés
// and long where it did not.
#let band-for(c) = arc(c.interval.lo, c.interval.hi).map(p => (:..p, country: c.country))
// The tick crosses the swirl at first place, so it reads as a position rather
// than as one more arc.
#let tick-reach = 0.065
#let tick = {
  let m = fastest.index
  let inner = on-ray(m, radius-at(m) - tick-reach)
  let outer = on-ray(m, radius-at(m) + tick-reach)
  ((x: inner.x, y: inner.y, xend: outer.x, yend: outer.y),)
}

// The quarters, written into the bezel so a position on the rim reads as a time
// whichever turn it belongs to.
#let numerals = (0, 15, 30, 45).map(m => (
  ..on-ray(m, (disc + bezel) / 2),
  label: if m == 0 { "0 min" } else { str(m) },
))

// The swirl runs clockwise and outwards, and nothing else on the dial says so.
#let heading = ((
  ..on-ray(spiral-end, radius-at(spiral-end) - 0.1),
  label: "longer",
),)

// Ink and paper come from the theme that typst-render resolved. The cup does
// not: it is a solid object drawn in its own colours, so it reads the same on
// the light and the dark surface.
#let ink = theme-minimal().at("ink", default: black)
#let note-colour = ink.transparentize(20%)

#let coffee = rgb("#3e2a21")
#let foam = rgb("#f2e6d3")
#let amber = rgb("#e9a33c")

// Bitter, for the title, is a slab serif with the weight of a menu board, Karla
// a grotesque that stays legible at label size. Both are vendored in
// assets/fonts, so CI renders them too.
#let body-font = "Karla"

#let as-time(minutes) = {
  let whole = calc.floor(minutes)
  let seconds = calc.floor((minutes - whole) * 60)
  str(whole) + ":" + if seconds < 10 { "0" } else { "" } + str(seconds)
}

// Callouts leave the cup along their own ray, then run out to a column of
// labels on the side they already point at. Slots are handed out top to bottom
// in the order the marks stand, so no two leaders cross.
// The labels stand well out from the rim, so the callouts use the width the
// circle leaves spare instead of crowding the cup.
#let callout-x = bezel + 0.9
#let slot-top = panel-half-y - 0.16
#let slot-bottom = -slot-top

#let callouts = {
  let picked = named.map(name => {
    let c = country-at(name)
    let p = point-at(c.index)
    (:..c, ..p, side: if p.x >= 0 { 1 } else { -1 })
  })
  let out = ()
  for side in (-1, 1) {
    let column = picked.filter(c => c.side == side).sorted(key: c => -c.y)
    let n = column.len()
    for (i, c) in column.enumerate() {
      let slot = if n == 1 { 0 } else { slot-top - (slot-top - slot-bottom) * i / (n - 1) }
      let elbow = on-ray(c.index, bezel + 0.05)
      out.push((
        ..c,
        elbow-x: elbow.x,
        // A ray pointing straight up or down would put the elbow past the edge
        // of the panel, so it is held just inside the rim instead.
        elbow-y: calc.max(calc.min(elbow.y, slot-top), slot-bottom),
        label-x: side * callout-x,
        label-y: slot,
      ))
    }
  }
  out
}

// Each callout is two segments: the mark out to its elbow past the rim, then
// the elbow across to its label. Both carry the same ink, so they are one
// layer.
#let leaders = (
  callouts.map(c => (x: c.x, y: c.y, xend: c.elbow-x, yend: c.elbow-y))
    + callouts.map(c => (x: c.elbow-x, y: c.elbow-y, xend: c.label-x, yend: c.label-y))
)

// Name and time only. How many cafés a country was surveyed at is already on
// the page, as the length of its arc.
#let label-text(c) = box[
  #text(
    font: body-font,
    size: 7.5pt,
    weight: "bold",
    fill: if c.country in (fastest.country, runner-up.country) { amber.darken(15%) } else { ink },
  )[#c.country]
  #text(font: body-font, size: 7.5pt, fill: note-colour)[#as-time(c.index)]
]

#let called(name) = box(text(fill: amber.darken(15%), weight: "bold")[#name])

// One row per label, so the column is drawn as a layer rather than as six
// single-row annotations. The anchor is a layer parameter, not an aesthetic, so
// the two columns take one layer each.
#let label-rows = callouts.map(c => (
  :..c,
  text-x: c.label-x + c.side * 0.04,
  content: label-text(c),
))

// Where the hand crosses twelve again. Without these the spiral is unreadable:
// a mark on the third turn is three hours, not three minutes. Each label sits
// exactly on its own crossing, not in the gap beside it, or it reads as naming
// the turn below. Each label carries a patch of coffee to break the line behind
// it.
#let hours = {
  range(1, calc.floor(spiral-end / turn) + 1).map(h => (
    x: 0,
    y: radius-at(h * turn),
    label: box(
      fill: coffee,
      inset: (x: 2.5pt, y: 0.5pt),
      text(font: body-font, size: 5.5pt, fill: foam.transparentize(25%))[#h h],
    ),
  ))
}

#plot(
  data: drawn.map(c => (:..point-at(c.index), ..c)),
  mapping: aes(x: "x", y: "y"),
  layers: (
    // The cup, from the rim inwards.
    geom-polygon(
      data: circle-at(bezel),
      fill: rgb("#6b4a35"),
      colour: rgb("#d9d2c7"),
      stroke: 1.6pt,
    ),
    geom-polygon(
      data: circle-at(disc),
      fill: coffee,
      stroke: none,
    ),
    // The swirl: the working-time axis, one hour per turn.
    geom-path(
      data: arc(0, spiral-end, steps: 900),
      colour: foam,
      alpha: 0.22,
      stroke: 0.7pt,
      arrow: arrow(length: 5pt),
    ),
    geom-text(
      data: heading,
      mapping: aes(label: "label"),
      size: 5.5pt,
      font: body-font,
      colour: foam,
      alpha: 0.55,
    ),
    // Each country's interval, thickened along the same swirl, so the doubt is
    // an arc of the clock and reads in the same units as the index. They are
    // translucent, because where the countries crowd, the arcs overlap, and the
    // overlap is the point: the brighter the cream, the less the order means.
    geom-path(
      data: named
        .filter(name => name != runner-up.country)
        .map(name => band-for(country-at(name)))
        .flatten(),
      mapping: aes(group: "country"),
      colour: foam,
      alpha: 0.75,
      stroke: 1.6pt,
    ),
    // The published index, for every country drawn. The dark outline keeps the
    // dot visible where it sits on its own arc.
    geom-point(
      data: d => d.filter(c => c.country != fastest.country),
      size: 1.7pt,
      fill: foam,
      colour: coffee,
      stroke: 0.45pt,
    ),
    // The comparison the title is about, and the only amber on the page.
    // Second place gets the arc, first place a radial tick, so the one visibly
    // straddles the other instead of two amber arcs overlapping into a blur.
    geom-path(
      data: band-for(runner-up),
      mapping: aes(group: "country"),
      colour: amber,
      stroke: 3pt,
    ),
    geom-segment(
      data: tick,
      mapping: aes(xend: "xend", yend: "yend"),
      colour: amber,
      stroke: 2pt,
    ),
    geom-typst(
      data: hours,
      mapping: aes(label: "label"),
    ),
    geom-text(
      data: numerals,
      mapping: aes(label: "label"),
      size: 6.5pt,
      font: body-font,
      colour: foam,
      alpha: 0.8,
    ),
    geom-segment(
      data: leaders,
      mapping: aes(xend: "xend", yend: "yend"),
      colour: note-colour,
      alpha: 0.55,
      stroke: 0.4pt,
    ),
    geom-typst(
      data: label-rows.filter(c => c.side < 0),
      mapping: aes(x: "text-x", y: "label-y", label: "content"),
      anchor: "east",
    ),
    geom-typst(
      data: label-rows.filter(c => c.side > 0),
      mapping: aes(x: "text-x", y: "label-y", label: "content"),
      anchor: "west",
    ),
  ),
  scales: scales(
    // The x range holds the cup and the two label columns. The fixed coord
    // keeps the cup a circle whatever the size of the figure.
    x: scale-continuous(limits: (-callout-x - 1, callout-x + 1), expand: (0%, 0%)),
    y: scale-continuous(limits: (-panel-half-y, panel-half-y), expand: (0%, 0%)),
  ),
  coord: coord-fixed(ratio: 1),
  guides: guides(default: none),
  labels: labels(
    title: "Second Place Is Fifteen Cafés Wide",
    subtitle: [
      One turn of the cup is an hour, and each mark is the minutes and seconds a barista works to buy one small cappuccino. \
      #called(fastest.country) is first at #as-time(fastest.index) on #comma(fastest.n) cafés. #called(runner-up.country) is second at #as-time(runner-up.index) on #comma(runner-up.n), and its 95% arc reaches under first place and past fourth.
    ],
    caption: [
      Only the #comma(drawn.len()) of #comma(countries.len()) countries surveyed at #min-sample cafés or more are drawn. The other #comma(thin.len()) rest on fewer, and #comma(solo.len()) on exactly one, yet the table prints all of them to the second. \
      An arc is drawn for the six named countries only. It is the normal interval for a ratio of sums, clipped at zero, and covers café sampling alone. Tips are excluded. \
      Source: James Hoffmann's cappuccino survey (TidyTuesday 2026-09-08). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: none,
  ),
  theme: theme-void(
    plot-title: element-text(font: "Bitter", size: 16pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8pt),
    plot-caption: element-text(font: body-font, size: 6pt),
    plot-background: element-rect(),
  ),
  width: auto,
  height: auto,
)
