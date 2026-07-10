// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.4.1": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Group a whole number with thousands separators, e.g. 5991 -> "5,991".
#let thousands(n) = {
  let out = ()
  for (i, c) in str(calc.abs(n)).clusters().rev().enumerate() {
    if i > 0 and calc.rem(i, 3) == 0 { out.push(",") }
    out.push(c)
  }
  out.rev().join()
}
#let pct(part, whole) = calc.round(100 * part / whole)

// One aggregated row per men's division: counts of fights ending by KO/TKO,
// submission, or decision. Ordered lightest to heaviest by the division weight
// limit, so nothing about the trend is typed by hand.
#let raw = csv("data/finish_by_class.csv", row-type: dictionary)
#let rows = raw.map(r => (
  class: r.weight_class,
  lb: int(r.weight_lb),
  order: int(r.order),
  ko: int(r.ko),
  sub: int(r.sub),
  dec: int(r.dec),
  n: int(r.n),
))

#let n-classes = rows.len()
#let n-total = rows.map(r => r.n).sum()
// The two divisions the callouts single out, found by weight rather than named.
#let light = rows.first()
#let heavy = rows.last()

// One palette, one source of truth. The finish is colour-coded by how the fight
// ends: a vermillion strike for the knockout (the hero), a cool blue for the
// submission, and a quiet warm grey for a fight that goes to the judges. The
// three stay distinct under every colour-vision deficiency.
#let ko-col = rgb("#d55e00") // KO/TKO: the finish that lands hardest
#let sub-col = rgb("#5f8aa8") // submission: the flat middle, muted so it recedes behind the hero
#let dec-col = rgb("#a9a198") // decision: no finish, left to the scorecards
#let seg-edge = rgb("#3333334d") // thin edge so segments split on light or dark paper
#let body-font = "Fira Sans"
#let chart-font = "Oswald" // condensed scoreboard face, downloaded to ~/Library/Fonts
#let ring-col = rgb("#7a3300") // burnt vermillion: reads on the pale and the dark paper

// Flyweight sits at the top, heavyweight at the bottom, so the red knockout
// wedge widens as the eye travels down into the heavier divisions.
#let ypos(r) = n-classes - r.order + 1
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

// Two-line tick label: the division name over its weight limit, so the axis
// itself states that the rows are ordered by how heavy the fighters are.
#let y-breaks = rows.map(r => ypos(r))
#let y-labels = rows.map(r => box(inset: (right: 2pt))[
  #set align(right)
  #text(font: chart-font, size: 9pt, weight: "bold")[#upper(r.class)] \
  #text(font: body-font, size: 6.5pt, fill: dec-col.darken(20%))[#r.lb lb]
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
  label: text(font: chart-font, fill: rgb("#ffffff"), weight: "bold", size: 9.5pt)[#pct(r.ko, r.n)%],
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
    // A faint dashed line at the halfway mark: the heavyweight knockout wedge is
    // the only bar that reaches past it.
    geom-vline(xintercept: 50, stroke: 0.7pt, colour: rgb("#88888899"), linetype: "dashed", inherit-aes: false),
    // The knockout share, white on vermillion, on every bar: the number that
    // carries the story.
    geom-typst(data: ko-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // The decision share, dark ink on the quiet grey, closing each bar at 100%.
    geom-typst(data: dec-labels, mapping: aes(x: "x", y: "y", label: "label"), inherit-aes: false),
    // One accent ring traces the heavyweight knockout wedge, tying its callout
    // to the data without recolouring the segment.
    annotate(
      "rect",
      xmin: 0, xmax: 100 * heavy.ko / heavy.n, ymin: ypos(heavy) - half, ymax: ypos(heavy) + half,
      fill: none, stroke: 1.3pt, colour: ring-col, clip: false,
    ),
    // One callout, in the right-hand gutter opened by the x-scale expansion and
    // aligned to the heavyweight bar so it never lands on the data. Vermillion
    // reads on both the pale and the dark paper, keeping this file self-contained.
    annotate("typst", x: 101, y: ypos(heavy), label: box(width: 3cm)[#note(fill: ko-col, size: 7.5pt, weight: "bold")[Over half of heavyweight bouts (#pct(heavy.ko, heavy.n)%) end in a knockout.]], anchor: "west", clip: false),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Share of Fights, by How They Ended",
      breaks: (0, 25, 50, 75, 100),
      labels: ("0", "25", "50", "75", "100%"),
      limits: (0, 100),
      // Right-hand gutter for the heavyweight callout.
      expand: (0%, 28%),
    ),
    y: scale-continuous(
      name: none,
      breaks: y-breaks,
      labels: y-labels,
      limits: (0.4, n-classes + 1),
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
      #text(fill: ko-col, weight: "bold")[knockout] climbs from #pct(light.ko, light.n)% among flyweights to #pct(heavy.ko, heavy.n)% among heavyweights,
      while the #text(fill: dec-col.darken(25%), weight: "bold")[decision] share falls the same way.
      #text(fill: sub-col.darken(20%), weight: "bold")[Submissions] stay near one in five throughout.
    ],
    caption: typst([
      Men's divisions only, #thousands(n-total) fights (2010–2026); ordered by weight limit. Draws, disqualifications and no-contests excluded. \
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
    axis-ticks-x: element-line(),
    tick-length: 0.1cm,
  ),
  width: auto,
  height: auto,
)
