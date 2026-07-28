// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.4.1": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

#let raw = csv("data/wreck_inventory.csv", row-type: dictionary)

// Dataset totals and the two decades the callouts single out, all read from the
// data so no headline number is typed by hand.
#let n-total = raw.len()
#let n-dated = raw.filter(r => r.year != "NA").len()
#let famine = 1850
#let pivot = 1910

// Group a whole number with thousands separators, e.g. 1382 -> "1,382".
#let thousands(n) = {
  let out = ()
  for (i, c) in str(calc.abs(n)).clusters().rev().enumerate() {
    if i > 0 and calc.rem(i, 3) == 0 { out.push(",") }
    out.push(c)
  }
  out.rev().join()
}
#let pct(part, whole) = calc.round(100 * part / whole)

// One palette, one source of truth. Cool depths read on both the light and dark
// site paper; a single vermillion accent is reserved for the WWI pivot so the
// eye lands there.
#let found-col = rgb("#16b6c8") // surface: located wrecks, crisp near the light
#let lost-col = rgb("#7aa6c6") // a mid steel-blue that lifts off the water at every depth
#let bar-edge = rgb("#0c2b42") // thin dark edge so every column reads against the sea
#let accent = rgb("#d55e00") // the WWI pivot ring and bars (graphical mark, 3:1)
#let accent-ink = rgb("#9c3f00") // a darker orange for the pivot callout text, legible on pale surface water
#let body-font = "PT Serif"
#let chart-font = "Libre Caslon Text"

// The story runs on dated wrecks; undated records carry no year to place on the
// timeline. A wreck is "found" when it has coordinates in the inventory.
#let d-min = 1750
#let d-max = 2010
#let counts = (:)
#for r in raw {
  if r.year == "NA" { continue }
  let y = int(float(r.year))
  if y < d-min or y > 2019 { continue }
  let dec = calc.floor(y / 10) * 10
  if dec > d-max { dec = d-max }
  let key = str(dec)
  let located = r.latitude != "NA" and r.longitude != "NA"
  let cur = counts.at(key, default: (found: 0, lost: 0))
  if located { cur.found += 1 } else { cur.lost += 1 }
  counts.insert(key, cur)
}

#let decades = range(d-min, d-max + 1, step: 10)
#let cell(d) = counts.at(str(d), default: (found: 0, lost: 0))
// Found rise above the waterline; lost sink below it. Two layers, not one
// stacked column, so each fate keeps its own colour and haze.
#let found-bars = decades.map(d => (decade: d, n: cell(d).found))
#let lost-bars = decades.map(d => (decade: d, n: -1 * cell(d).lost))

// The water column: light at the surface, darkening into the deep. The vertical
// position of a wreck is its fate, so the gradient is the found-to-lost axis,
// not decoration.
#let water = gradient.linear(
  (rgb("#dcecf3"), 0%),
  (rgb("#a9d2e5"), 20%),
  (rgb("#6ba0c1"), 33%),
  (rgb("#356f95"), 52%),
  (rgb("#1d4560"), 80%),
  (rgb("#0f2c42"), 100%),
  angle: 90deg,
)

// Annotation helper: quiet serif set on the murk, so callouts read without a
// legend.
#let note(body, fill: rgb("#eef4f9"), size: 7.5pt, weight: "regular") = text(
  size: size,
  fill: fill,
  font: body-font,
  weight: weight,
)[#body]

#plot(
  data: found-bars,
  mapping: aes(x: "decade", y: "n"),
  layers: (
    // Waterline: the split between found and lost.
    geom-hline(yintercept: 0, stroke: 0.8pt, colour: rgb("#eaf4f8"), alpha: 0.9),
    // Lost below, found above; both carry a thin edge so they read at any depth.
    geom-col(fill: found-col, stroke: 0.4pt, colour: bar-edge),
    geom-col(data: lost-bars, fill: lost-col, stroke: 0.4pt, colour: bar-edge),
    // One accent ring traces the WWI pivot column (bar half-width is 4.5 = the
    // 10-year slot times the 0.9 default), tying its callout to the data without
    // recolouring the fates inside it.
    geom-rect(
      data: ((xmin: pivot - 4.5, xmax: pivot + 4.5, ymin: -1 * cell(pivot).lost, ymax: cell(pivot).found),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      fill: none, stroke: 1.3pt, colour: accent, inherit-aes: false,
    ),
    // A quieter off-white ring traces the 1850s famine column, matching its callout.
    geom-rect(
      data: ((xmin: famine - 4.5, xmax: famine + 4.5, ymin: -1 * cell(famine).lost, ymax: cell(famine).found),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      fill: none, stroke: 1.3pt, colour: rgb("#eef4f9"), inherit-aes: false,
    ),
    // Direction cues near the left edge, in the water.
    annotate("typst", x: 1745, y: 550, label: note(fill: rgb("#0d3450"), weight: "bold")[▲ found · mapped], anchor: "west", clip: false),
    annotate("typst", x: 1745, y: -750, label: note(fill: rgb("#eaf4f8"), weight: "bold")[▼ lost · no position], anchor: "west", clip: false),
    // The famine decade: the deepest loss, almost none of it located.
    annotate("typst", x: famine - 3, y: -1180, label: box(width: 4.4cm)[#note(size: 8pt)[*#(str(famine) + "s") famine-era exodus:* #thousands(cell(famine).lost) wrecks lost, #pct(cell(famine).lost, cell(famine).found + cell(famine).lost)% never located.]], anchor: "east", clip: false),
    // The turning point.
    annotate("typst", x: pivot, y: 665, label: box(width: 3.4cm)[#set align(center); #note(fill: accent-ink, size: 8pt, weight: "bold")[WWI turning point \ #(str(pivot) + "s"): #pct(cell(pivot).found, cell(pivot).found + cell(pivot).lost)% found (#thousands(cell(pivot).found))]], anchor: "south", clip: false),
    // The modern tail.
    annotate("typst", x: 1978, y: 470, label: box(width: 3cm)[#set align(center); #note(fill: rgb("#0d3450"), size: 7.5pt)[Since 1950, nearly every wreck is charted]], anchor: "south", clip: false),
    // A wreck settling on the seabed, in the deep bottom-right corner (its faint
    // steel tint is set in wreck.svg).
    annotate("typst", x: 2024, y: -1520, label: image("assets/wreck.svg", width: 2.7cm), anchor: "south-east", clip: false),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Decade of Loss",
      breaks: (1750, 1800, 1850, 1900, 1950, 2000),
      limits: (1743, 2018),
      expand: (0%, 0%),
    ),
    y: scale-continuous(
      name: "Wrecks per Decade · Found Above, Lost Below",
      breaks: (-1000, -500, 0, 500),
      labels: ("1,000", "500", "0", "500"),
      limits: (-1480, 1050),
      expand: (0%, 0%),
    ),
  ),
  guides: guides(default: none),
  labels: labels(
    title: "The Older the Wreck, the Deeper It Stays Lost",
    subtitle: [
      Of #thousands(n-total) recorded Irish shipwrecks, only one in five has ever been given coordinates.
      Decade by decade the share #text(fill: found-col, weight: "bold")[found] (above the waterline) climbs from almost none before 1840 to nearly all after 1950;
      the #text(fill: lost-col, weight: "bold")[rest] sink unlocated into the deep.
    ],
    caption: typst([
      Dated wrecks only (#thousands(n-dated) of #thousands(n-total)); the rising found-share partly reflects steel hulls and modern sonar, not recency alone. \
      Source: Wreck Inventory of Ireland (TidyTuesday 2026-06-30). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL]. Ship-wreck icon: Delapouite, #link("https://game-icons.net")[game-icons.net].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 15pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7.5pt),
    panel-background: element-rect(fill: water),
    panel-grid: element-blank(),
    axis-ticks: element-tick(length: 0.1cm),
  ),
  width: auto,
  height: auto,
)
