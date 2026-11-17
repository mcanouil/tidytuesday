// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

#let raw = csv("data/wreck_inventory.csv", row-type: dictionary)

// Dataset totals and the two decades the callouts name, all read from the data.
#let n-total = raw.len()
#let n-dated = raw.filter(r => r.year != "NA").len()
#let famine = 1850
#let pivot = 1910

// One palette, one source of truth. The cool depths read on both surfaces, and
// one vermillion accent is reserved for the WWI pivot.
#let found-col = rgb("#16b6c8") // surface: located wrecks, crisp near the light
#let lost-col = rgb("#7aa6c6") // a mid steel-blue that lifts off the water at every depth
#let bar-edge = rgb("#0c2b42") // thin dark edge so every column reads against the sea
#let accent = rgb("#d55e00") // the WWI pivot ring and bars (graphical mark, 3:1)
#let body-font = "PT Serif"

// The story runs on dated wrecks. An undated record has no year for the
// timeline. A wreck is "found" when it carries coordinates in the inventory.
#let d-min = 1750
#let d-max = 2010
#let wrecks = {
  raw
    .filter(r => r.year != "NA")
    .map(r => {
      let y = int(float(r.year))
      (
        year: y,
        decade: calc.min(calc.floor(y / 10) * 10, d-max),
        fate: if r.latitude != "NA" and r.longitude != "NA" { "found" } else { "lost" },
      )
    })
    .filter(r => r.year >= d-min and r.year <= 2019)
}

// One row per decade with a column for each fate. A fate with no wreck in a
// decade is none, which reads as zero.
#let by-decade = (
  pivot-wider(
    count(wrecks, "decade", "fate"),
    names-from: "fate",
    values-from: "n",
  )
    .map(r => (str(r.decade), r))
    .to-dict()
)
#let or-zero(n) = if n == none { 0 } else { n }
#let cell(d) = {
  let r = by-decade.at(str(d))
  (found: or-zero(r.found), lost: or-zero(r.lost))
}

// Found rise above the waterline and lost sink below it, so the lost counts
// carry a minus sign.
#let bars = (
  by-decade
    .values()
    .map(r => (
      (decade: r.decade, fate: "found", n: or-zero(r.found)),
      (decade: r.decade, fate: "lost", n: -or-zero(r.lost)),
    ))
    .flatten()
)
// Annotation helper: a quiet serif on the murk, so callouts read without a
// legend.
#let note(body, fill: rgb("#eef4f9"), size: 7.5pt, weight: "regular") = text(
  size: size,
  fill: fill,
  font: body-font,
  weight: weight,
)[#body]

#plot(
  data: bars,
  mapping: aes(x: "decade", y: "n", fill: "fate"),
  layers: (
    geom-hline(yintercept: 0, stroke: 0.8pt, colour: rgb("#eaf4f8"), alpha: 0.9),
    // Lost below, found above. Both carry a thin edge, so they read at any depth.
    geom-col(stroke: 0.4pt, colour: bar-edge),
    // An accent ring traces the WWI pivot column and ties its callout to the
    // data. The bar half-width is 4.5: the 10-year slot times the 0.9 default.
    geom-rect(
      data: ((xmin: pivot - 4.5, xmax: pivot + 4.5, ymin: -cell(pivot).lost, ymax: cell(pivot).found),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      fill: none, stroke: 1.3pt, colour: accent, inherit-aes: false,
    ),
    // A quieter off-white ring traces the 1850s famine column, to match its
    // callout.
    geom-rect(
      data: ((xmin: famine - 4.5, xmax: famine + 4.5, ymin: -cell(famine).lost, ymax: cell(famine).found),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      fill: none, stroke: 1.3pt, colour: rgb("#eef4f9"), inherit-aes: false,
    ),
    annotate("typst", x: 1745, y: 550, label: note(fill: rgb("#0d3450"), weight: "bold")[▲ found · mapped], anchor: "west", clip: false),
    annotate("typst", x: 1745, y: -750, label: note(fill: rgb("#eaf4f8"), weight: "bold")[▼ lost · no position], anchor: "west", clip: false),
    annotate("typst", x: famine - 3, y: -1180, label: box(width: 4.4cm)[#note(size: 8pt)[*#(str(famine) + "s") famine-era exodus:* #format-comma(digits: 0)(cell(famine).lost) wrecks lost, #format-percent()(cell(famine).lost / (cell(famine).found + cell(famine).lost)) never located.]], anchor: "east", clip: false),
    // A darker orange than the accent keeps the pivot callout text legible on pale
    // surface water.
    annotate("typst", x: pivot, y: 665, label: box(width: 3.4cm)[#set align(center); #note(fill: rgb("#9c3f00"), size: 8pt, weight: "bold")[WWI turning point \ #(str(pivot) + "s"): #format-percent()(cell(pivot).found / (cell(pivot).found + cell(pivot).lost)) found (#format-comma(digits: 0)(cell(pivot).found))]], anchor: "south", clip: false),
    annotate("typst", x: 1978, y: 470, label: box(width: 3cm)[#set align(center); #note(fill: rgb("#0d3450"), size: 7.5pt)[Since 1950, nearly every wreck is charted]], anchor: "south", clip: false),
    // A wreck on the seabed, in the deep bottom-right corner. Its steel tint is
    // set in wreck.svg.
    annotate("typst", x: 2018, y: -1480, label: image("assets/wreck.svg", width: 2.7cm), anchor: "south-east", clip: false),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Decade of Loss",
      breaks: (1750, 1800, 1850, 1900, 1950, 2000),
      limits: (1743, 2018),
      expand: (0%, 0%),
    ),
    fill: scale-manual(values: (found-col, lost-col), limits: ("found", "lost")),
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
      Of #format-comma(digits: 0)(n-total) recorded Irish shipwrecks, only one in five has ever been given coordinates.
      Decade by decade the share #text(fill: found-col, weight: "bold")[found] (above the waterline) climbs from almost none before 1840 to nearly all after 1950;
      the #text(fill: lost-col, weight: "bold")[rest] sink unlocated into the deep.
    ],
    caption: typst([
      Dated wrecks only (#format-comma(digits: 0)(n-dated) of #format-comma(digits: 0)(n-total)); the rising found-share partly reflects steel hulls and modern sonar, not recency alone. \
      Source: Wreck Inventory of Ireland (TidyTuesday 2026-06-30). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL]. Ship-wreck icon: Delapouite, #link("https://game-icons.net")[game-icons.net].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: "Libre Caslon Text", size: 15pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7.5pt),
    // The water column: light at the surface, dark in the deep. Vertical position
    // is the fate of a wreck, so the gradient is the found-to-lost axis.
    panel-background: element-rect(fill: gradient.linear(
      (rgb("#dcecf3"), 0%),
      (rgb("#a9d2e5"), 20%),
      (rgb("#6ba0c1"), 33%),
      (rgb("#356f95"), 52%),
      (rgb("#1d4560"), 80%),
      (rgb("#0f2c42"), 100%),
      angle: 90deg,
    )),
    panel-grid: element-blank(),
    axis-ticks: element-tick(length: 0.1cm),
  ),
  width: auto,
  height: auto,
)
