// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Group a whole number with thousands separators, e.g. 8258 -> "8,258".
#let thousands = format-comma(digits: 0)
#let pct(part, whole) = format-percent(digits: 0)(part / whole)
// Division limits are stated in pounds. This converts them to whole kilograms,
// so no weight is typed by hand twice.
#let kg(lb) = calc.round(lb * 0.45359237)

// Every number below comes from the raw fight table.
// Source: data/ufc_fights.csv, one row per UFC bout (UFCStats via {fightr}).
#let raw = csv("data/ufc_fights.csv", row-type: dictionary)

// Canonical division names, longest first, so "Light Heavyweight" matches before
// "Heavyweight" when scanned inside the raw "weight_class". That column carries
// prefixes and suffixes such as "UFC ... Title" and " Bout".
#let div-names = (
  "Light Heavyweight", "Heavyweight", "Middleweight", "Welterweight",
  "Lightweight", "Featherweight", "Bantamweight", "Flyweight", "Strawweight",
)
#let division-of(wc) = {
  for n in div-names { if wc.contains(n) { return n } }
  none
}

// Collapse the raw "method" strings into the three finish types the chart shows.
// A disqualification, an overturned result or a stoppage is not a finish, so it
// is dropped.
#let finish-of(m) = {
  if m.starts-with("KO/TKO") { "ko" } else if m.starts-with("Submission") {
    "sub"
  } else if m.starts-with("Decision") { "dec" } else { none }
}

// One pass over the raw fights, counting knockouts, submissions and decisions per
// gender and division, keyed "Gender|Division". A weight class with no fixed
// limit has no position on the weight axis, so it is excluded.
#let no-limit = ("Open Weight", "Catch Weight", "Tournament")
#let fights = {
  raw
    .filter(r => not no-limit.any(w => r.weight_class.contains(w)))
    .map(r => (
      gender: if r.weight_class.contains("Women's") { "Women" } else { "Men" },
      division: division-of(r.weight_class),
      finish: finish-of(r.method),
    ))
    .filter(r => r.division != none and r.finish != none)
}

#let tally = count(fights, "gender", "division", "finish")
#let finishes(gender, division, finish) = {
  let hit = tally.find(t => (
    t.gender == gender and t.division == division and t.finish == finish
  ))
  if hit == none { 0 } else { hit.n }
}

// The divisions to draw, lightest to heaviest within each gender, each with its
// weight limit in pounds. The order is stated once here.
#let spec = (
  (gender: "Men", class: "Flyweight", lb: 125),
  (gender: "Men", class: "Bantamweight", lb: 135),
  (gender: "Men", class: "Featherweight", lb: 145),
  (gender: "Men", class: "Lightweight", lb: 155),
  (gender: "Men", class: "Welterweight", lb: 170),
  (gender: "Men", class: "Middleweight", lb: 185),
  (gender: "Men", class: "Light Heavyweight", lb: 205),
  (gender: "Men", class: "Heavyweight", lb: 265),
  (gender: "Women", class: "Strawweight", lb: 115),
  (gender: "Women", class: "Flyweight", lb: 125),
  (gender: "Women", class: "Bantamweight", lb: 135),
  (gender: "Women", class: "Featherweight", lb: 145),
)
#let rows = spec.enumerate().map(((i, s)) => {
  let ko = finishes(s.gender, s.class, "ko")
  let sub = finishes(s.gender, s.class, "sub")
  let dec = finishes(s.gender, s.class, "dec")
  (
    gender: s.gender, class: s.class, lb: s.lb, order: i + 1,
    ko: ko, sub: sub, dec: dec, n: ko + sub + dec,
  )
})

#let n-total = rows.map(r => r.n).sum()
// The divisions the callouts name, found by gender and weight rather than by row
// position.
#let find-row(gender, cls) = rows.find(r => r.gender == gender and r.class == cls)
#let m-light = find-row("Men", "Flyweight")
#let m-heavy = find-row("Men", "Heavyweight")

// One palette, one source of truth. Vermillion is the knockout, blue the
// submission, and a warm grey the fight that goes to the judges. The three stay
// distinct under every colour-vision deficiency.
#let ko-col = rgb("#d55e00") // KO/TKO: the finish that lands hardest
#let sub-col = rgb("#5f8aa8") // submission: the flat middle, muted so it recedes behind the hero
#let dec-col = rgb("#a9a198") // decision: no finish, left to the scorecards
#let seg-edge = rgb("#3333334d") // thin edge so segments split on light or dark paper
#let body-font = "Fira Sans"
#let chart-font = "Oswald" // condensed scoreboard face
#let ring-col = rgb("#7a3300") // burnt vermillion: reads on the pale and the dark paper
#let ink = rgb("#1c1c1c") // near-black text ink, so nothing on the page is pure #000
#let paper-white = rgb("#faf6f0") // warm off-white for the KO label, never pure #fff
#let guide-col = rgb("#2b2b2bcc") // dark neutral for the 50% guide: holds contrast on the vermillion, blue and grey segments alike

// Men on top, women below, lightest to heaviest in each group, so the knockout
// wedge widens downward. A one-row gap separates the two genders.
#let gap = 1
#let slot(r) = if r.gender == "Men" { r.order } else { r.order + gap }
#let n-slots = spec.len() + gap
#let ypos(r) = n-slots - slot(r) + 1
#let half = 0.38

// Each bar is three segments from 0 to 100 percent: knockout at the left edge,
// then submission, then decision.
#let segs = ()
#for r in rows {
  let y = ypos(r)
  let ko-p = 100 * r.ko / r.n
  let sub-p = 100 * r.sub / r.n
  segs.push((xmin: 0, xmax: ko-p, ymin: y - half, ymax: y + half, cat: "KO/TKO"))
  segs.push((xmin: ko-p, xmax: ko-p + sub-p, ymin: y - half, ymax: y + half, cat: "Submission"))
  segs.push((xmin: ko-p + sub-p, xmax: 100, ymin: y - half, ymax: y + half, cat: "Decision"))
}

// Two-line tick label: the division name over its gender and weight limit, so
// the axis states the gender and the ordering itself.
#let y-breaks = rows.map(r => ypos(r))
#let y-labels = rows.map(r => box(inset: (right: 2pt))[
  #set align(right)
  #text(font: chart-font, size: 9pt, weight: "bold")[#upper(r.class)] #text(font: body-font, size: 6.5pt, fill: dec-col.darken(20%))[#r.gender · #r.lb lb (#kg(r.lb) kg)]
])

#let note(body, fill: rgb("#f4f4f4"), size: 7.5pt, weight: "regular", font: body-font) = text(
  size: size,
  fill: fill,
  font: font,
  weight: weight,
)[#body]

// Per-row value labels on their own tables, one mark per division. The knockout
// share sits white on the vermillion wedge, and the decision share closes each
// bar in dark ink on the grey.
#let ko-labels = rows.map(r => (
  x: (100 * r.ko / r.n) / 2,
  y: ypos(r),
  label: text(font: chart-font, fill: paper-white, weight: "bold", size: 9.5pt)[#pct(r.ko, r.n)],
))
#let dec-labels = rows.map(r => (
  x: 100 - (100 * r.dec / r.n) / 2,
  y: ypos(r),
  label: text(font: chart-font, fill: rgb("#3a352f"), size: 8pt)[#pct(r.dec, r.n)],
))

#plot(
  data: segs,
  mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax", fill: "cat"),
  layers: (
    geom-rect(stroke: 0.4pt, colour: seg-edge),
    // A dashed line at the halfway mark, which only the men's heavyweight
    // knockout wedge passes. Dark neutral, so it holds across all three
    // segment colours.
    geom-vline(xintercept: 50, stroke: 0.8pt, colour: guide-col, linetype: "dashed", inherit-aes: false),
    // The knockout share, white on vermillion, on every bar.
    geom-typst(data: ko-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // The decision share, dark ink on the quiet grey, closing each bar at 100%.
    geom-typst(data: dec-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // An accent ring traces the men's heavyweight knockout wedge, tying its
    // callout to the data without recolouring the segment.
    annotate(
      "rect",
      xmin: 0, xmax: 100 * m-heavy.ko / m-heavy.n, ymin: ypos(m-heavy) - half, ymax: ypos(m-heavy) + half,
      fill: none, stroke: 1.3pt, colour: ring-col, clip: false,
    ),
    // One callout, in the gutter the x-scale expansion opens, aligned to the
    // heavyweight bar so it never lands on the data. Vermillion reads on both
    // surfaces.
    annotate("typst", x: 0, y: ypos(m-heavy) - 0.9, label: box(width: 9cm)[#note(fill: ko-col, size: 7.5pt, weight: "bold")[Over half of men's heavyweight bouts (#pct(m-heavy.ko, m-heavy.n)) end in a knockout.]], anchor: "west", clip: false),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Share of Fights, by How They Ended",
      breaks: (0, 25, 50, 75, 100),
      labels: ("0", "25", "50", "75", "100%"),
      limits: (0, 100),
      expand: (0.5%, 2%),
    ),
    y: scale-continuous(
      name: none,
      breaks: y-breaks,
      labels: y-labels,
      limits: (0.4, n-slots + 1),
      expand: (0%, 0%),
    ),
    fill: scale-manual(
      values: (ko-col, sub-col, dec-col),
      limits: ("KO/TKO", "Submission", "Decision"),
    ),
  ),
  guides: guides(default: none),
  labels: labels(
    title: "The Heavier the Division, the More Fights End in a Knockout",
    subtitle: [
      Across #thousands(n-total) UFC bouts, the share ending in a
      #text(fill: ko-col, weight: "bold")[knockout] climbs with the weight limit in both men's and women's divisions,
      from #pct(m-light.ko, m-light.n) of men's flyweight bouts to #pct(m-heavy.ko, m-heavy.n) of heavyweight,
      while the #text(fill: dec-col.darken(25%), weight: "bold")[decision] share falls the same way.
      #text(fill: sub-col.darken(20%), weight: "bold")[Submissions] stay near one in five throughout.
    ],
    caption: typst([
      Men's and women's divisions, #thousands(n-total) fights (1997–2026); ordered by weight limit within gender. \
      Open-weight, catch-weight and tournament bouts, and non-finishes (draws, disqualifications, no-contests) excluded. \
      Source: {fightr} package, UFCStats (TidyTuesday 2026-07-07). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7.5pt),
    panel-grid: element-blank(),
    axis-ticks: element-tick(length: 0.1cm),
  ),
  width: auto,
  height: auto,
)
