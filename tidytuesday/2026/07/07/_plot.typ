// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// importing it again here is redundant.
// #import "@preview/gribouille:0.6.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Group a whole number with thousands separators, e.g. 8258 -> "8,258".
#let thousands(n) = {
  let out = ()
  for (i, c) in str(calc.abs(n)).clusters().rev().enumerate() {
    if i > 0 and calc.rem(i, 3) == 0 { out.push(",") }
    out.push(c)
  }
  out.rev().join()
}
#let pct(part, whole) = calc.round(100 * part / whole)
// Division limits are stated in pounds; convert to whole kilograms for readers
// on the metric side, so nothing about the weight is typed by hand twice.
#let kg(lb) = calc.round(lb * 0.45359237)

// Every number below is derived from the raw fight table itself, so the chart is
// reproducible end to end: no hand-typed counts and no pre-summarised file.
// Source: data/ufc_fights.csv, one row per UFC bout (UFCStats via {fightr}).
#let raw = csv("data/ufc_fights.csv", row-type: dictionary)

// Canonical division names, longest first so "Light Heavyweight" matches before
// "Heavyweight" and "Featherweight" before "Flyweight" when scanned as a
// substring of the raw "weight_class" (which carries suffixes like " Bout" and
// prefixes like "UFC ... Title").
#let div-names = (
  "Light Heavyweight", "Heavyweight", "Middleweight", "Welterweight",
  "Lightweight", "Featherweight", "Bantamweight", "Flyweight", "Strawweight",
)
#let division-of(wc) = {
  for n in div-names { if wc.contains(n) { return n } }
  none
}

// Collapse the many raw "method" strings into the three finish types the chart
// shows; anything else (DQ, overturned, could-not-continue) is not a finish and
// is dropped.
#let finish-of(m) = {
  if m.starts-with("KO/TKO") { "ko" } else if m.starts-with("Submission") {
    "sub"
  } else if m.starts-with("Decision") { "dec" } else { none }
}

// One pass over the raw fights, tallying KO / submission / decision counts per
// gender and division into a dictionary keyed "Gender|Division". Weight classes
// with no fixed limit (open weight, catch weight, regional tournament bouts)
// carry no position on the weight axis and are excluded.
#let tally = (:)
#for r in raw {
  let wc = r.weight_class
  if wc.contains("Open Weight") or wc.contains("Catch Weight") or wc.contains("Tournament") {
    continue
  }
  let gender = if wc.contains("Women's") { "Women" } else { "Men" }
  let division = division-of(wc)
  if division == none { continue }
  let finish = finish-of(r.method)
  if finish == none { continue }
  let key = gender + "|" + division
  let c = tally.at(key, default: (ko: 0, sub: 0, dec: 0))
  c.insert(finish, c.at(finish) + 1)
  tally.insert(key, c)
}

// The divisions to draw, lightest to heaviest within each gender, each with its
// weight limit in pounds. Ordering is stated here once; the trend then falls out
// of the data rather than being arranged by hand.
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
  let c = tally.at(s.gender + "|" + s.class, default: (ko: 0, sub: 0, dec: 0))
  (
    gender: s.gender, class: s.class, lb: s.lb, order: i + 1,
    ko: c.ko, sub: c.sub, dec: c.dec, n: c.ko + c.sub + c.dec,
  )
})

#let n-total = rows.map(r => r.n).sum()
// The divisions the callouts single out, found by gender and weight rather than
// by row position, so they stay correct if the ordering changes.
#let find-row(gender, cls) = rows.find(r => r.gender == gender and r.class == cls)
#let m-light = find-row("Men", "Flyweight")
#let m-heavy = find-row("Men", "Heavyweight")

// One palette, one source of truth. The finish is colour-coded by how the fight
// ends: a vermillion strike for the knockout (the hero), a cool blue for the
// submission, and a quiet warm grey for a fight that goes to the judges. The
// three stay distinct under every colour-vision deficiency.
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

// Men on top, women below, lightest to heaviest within each group so the red
// knockout wedge widens downward. A one-row gap separates the two genders.
#let gap = 1
#let slot(r) = if r.gender == "Men" { r.order } else { r.order + gap }
#let n-slots = spec.len() + gap
#let ypos(r) = n-slots - slot(r) + 1
#let half = 0.38

// Each bar is three segments laid end to end from 0 to 100 percent: knockout
// anchored at the left edge (the growing wedge), then submission, then decision.
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
// the axis itself states the fighters' gender and that the rows are ordered by
// how heavy they are.
#let y-breaks = rows.map(r => ypos(r))
#let y-labels = rows.map(r => box(inset: (right: 2pt))[
  #set align(right)
  #text(font: chart-font, size: 9pt, weight: "bold")[#upper(r.class)] #text(font: body-font, size: 6.5pt, fill: dec-col.darken(20%))[#r.gender · #r.lb lb (#kg(r.lb) kg)]
])

// Annotation helper: quiet body face, so callouts read without a legend.
#let note(body, fill: rgb("#f4f4f4"), size: 7.5pt, weight: "regular", font: body-font) = text(
  size: size,
  fill: fill,
  font: font,
  weight: weight,
)[#body]

// Per-row value labels carried on their own tables, one mark per division. The
// knockout share sits white on the vermillion wedge (the hero number); the
// decision share closes each bar in dark ink on the quiet grey.
#let ko-labels = rows.map(r => (
  x: (100 * r.ko / r.n) / 2,
  y: ypos(r),
  label: text(font: chart-font, fill: paper-white, weight: "bold", size: 9.5pt)[#pct(r.ko, r.n)%],
))
#let dec-labels = rows.map(r => (
  x: 100 - (100 * r.dec / r.n) / 2,
  y: ypos(r),
  label: text(font: chart-font, fill: rgb("#3a352f"), size: 8pt)[#pct(r.dec, r.n)%],
))

#plot(
  data: segs,
  mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax", fill: "cat"),
  layers: (
    geom-rect(stroke: 0.4pt, colour: seg-edge),
    // A dashed line at the halfway mark: the men's heavyweight knockout wedge is
    // the only bar that reaches past it. Dark neutral so it stays legible where
    // it crosses the vermillion, blue and grey segments.
    geom-vline(xintercept: 50, stroke: 0.8pt, colour: guide-col, linetype: "dashed", inherit-aes: false),
    // The knockout share, white on vermillion, on every bar: the number that
    // carries the story.
    geom-typst(data: ko-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // The decision share, dark ink on the quiet grey, closing each bar at 100%.
    geom-typst(data: dec-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // One accent ring traces the men's heavyweight knockout wedge, tying its
    // callout to the data without recolouring the segment.
    annotate(
      "rect",
      xmin: 0, xmax: 100 * m-heavy.ko / m-heavy.n, ymin: ypos(m-heavy) - half, ymax: ypos(m-heavy) + half,
      fill: none, stroke: 1.3pt, colour: ring-col, clip: false,
    ),
    // One callout, in the right-hand gutter opened by the x-scale expansion and
    // aligned to the heavyweight bar so it never lands on the data. Vermillion
    // reads on both the pale and the dark paper, keeping this file self-contained.
    annotate("typst", x: 0, y: ypos(m-heavy) - 0.9, label: box(width: 9cm)[#note(fill: ko-col, size: 7.5pt, weight: "bold")[Over half of men's heavyweight bouts (#pct(m-heavy.ko, m-heavy.n)%) end in a knockout.]], anchor: "west", clip: false),
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
      from #pct(m-light.ko, m-light.n)% of men's flyweight bouts to #pct(m-heavy.ko, m-heavy.n)% of heavyweight,
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
