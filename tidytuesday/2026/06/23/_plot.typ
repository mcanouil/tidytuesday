// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.4.1": *
#import "@local/gribouille:0.0.0": *
#set page(width: 18cm, height: 9.45cm, margin: 0cm)

#let raw = csv("data/papal_encyclicals.csv", row-type: dictionary)

// Data key for the record holder, reused by every Leo XIII comparison so the
// string lives in one place.
#let leo-name = "Leo XIII"

// Count encyclicals per pope and keep each reign span for the y-axis labels.
#let pope-meta = (:)
#for r in raw {
  let p = r.pope
  if p not in pope-meta {
    // Reign years from the pontificate dates; "NA" end marks a sitting pope.
    let reign-end = if r.pontificate_end == "NA" { none } else {
      int(r.pontificate_end.slice(0, 4))
    }
    pope-meta.insert(p, (
      count: 1,
      reign-start: int(r.pontificate_start.slice(0, 4)),
      reign-end: reign-end,
    ))
  } else {
    let cur = pope-meta.at(p)
    pope-meta.insert(p, (..cur, count: cur.count + 1))
  }
}

// Leo XIII's 86 encyclicals tallied by year of his reign (1–25), feeding the
// inset that shows his output was sustained across the whole pontificate.
#let leo-counts = (:)
#for r in raw {
  if r.pope != leo-name { continue }
  let y = r.pontificate_year
  leo-counts.insert(y, leo-counts.at(y, default: 0) + 1)
}
#let leo-by-year = range(1, 26).map(y => (yr: y, n: leo-counts.at(str(y), default: 0)))

// Ranking is the message: order by count. The discrete y-axis draws its first
// level at the bottom, so ascending count puts Leo XIII (most) at the top.
#let ranked = pope-meta.pairs().map(pair => {
  (pope: pair.at(0), count: pair.at(1).count)
}).sorted(key: row => row.count)
#let pope-order = ranked.map(row => row.pope)

// Apex of the funnel, derived from the data so it pins to the real Leo XIII
// point: x just past his count, y at his 1-indexed level (top of the axis).
#let leo-count = pope-meta.at(leo-name).count
#let leo-level = pope-order.position(p => p == leo-name) + 1

// One muted ink for every pope; one warm accent reserved for the record holder
// so the eye lands on the single element that carries the message.
#let muted = luma(62%)
#let accent = rgb("#d55e00")
// x0 anchors each stem at zero; lx places the count label just past the point
// head (nudge-x is avoided: mapping it trips the discrete-scale trainer).
#let rows = ranked.map(row => (
  ..row,
  x0: 0,
  lx: row.count + 2,
  clabel: str(row.count),
  // Two-level grouping: the record holder versus everyone else, mapped through
  // colour/fill so a single segment and point layer carry the highlight.
  group: if row.pope == leo-name { leo-name } else { "Other" },
))

// Inset subplot: a small accent column chart of Leo XIII's encyclicals per year
// of reign, dropped into the empty bottom-right. The themed box reads `page.fill`
// so the inset tracks the light / dark site toggle, mirroring the 06/09 inset.
#let inset = context {
  let bg = if page.fill in (auto, none) { white } else { page.fill }
  box(
    fill: bg,
    inset: 6pt,
    radius: 3pt,
    stroke: 0.5pt + accent,
  )[
    #plot(
      data: leo-by-year,
      mapping: aes(x: "yr", y: "n"),
      layers: (geom-col(fill: accent, width: 0.7),),
      scales: (
        scale-x-continuous(breaks: (1, 5, 10, 15, 20, 25), expand: (0%, 0%)),
        scale-y-continuous(breaks: (0, 4, 8)),
      ),
      labels: labels(
        title: "Sustained: Encyclicals per Year of His 25-Year Reign",
        x: none,
        y: none,
      ),
      theme: theme-minimal(
        axis-text-x: element-text(size: 7pt),
        axis-text-y: element-text(size: 7pt),
        plot-title: element-text(align: center, size: 8pt, weight: "bold", colour: accent),
        // Stems carry the values; vertical gridlines only compete with them.
        panel-grid-major-x: element-blank(),
        panel-grid-minor-x: element-blank(),
      ),
      width: 8cm,
      height: 4.2cm,
    )
  ]
}

#plot(
  data: rows,
  mapping: aes(x: "count", y: "pope"),
  layers: (
    // Funnel connector: drawn first so the stems, point, count labels, and the
    // opaque inset box all sit on top, the box hiding the triangle's base edge.
    // `clip: false` (merged onto the layer dict, since geom-polygon has no clip
    // param) opts the layer out of the discrete out-of-range drop pre-pass, so
    // its fractional numeric y values survive instead of being filtered out.
    geom-polygon(
      data: (
        (x: 33.85, y: 8.53),
        (x: 82.5, y: 0.74),
        (x: leo-count + 0.25, y: leo-level),
      ),
      mapping: aes(x: "x", y: "y"),
      fill: accent,
      stroke: none,
      inherit-aes: false,
    ) + (clip: false),
    // Lollipop stem: length encodes the count on a common zero-based axis. The
    // group aesthetic tints the record holder accent and everyone else muted.
    geom-segment(
      mapping: aes(x: "x0", y: "pope", xend: "count", yend: "pope", colour: "group"),
      stroke: 1.4pt,
    ),
    geom-point(mapping: aes(fill: "group"), size: 3.4pt),
    // Direct count labels: the number sits at the head of each stem, so the
    // reader never hunts an axis tick to read "86". The record holder's count
    // is bold to match its highlighted stem and tick; the data function styles
    // each row's content conditionally.
    geom-typst(
      data: d => d.map(r => (
        ..r,
        lab: text(
          size: 8pt,
          fill: if r.pope == leo-name { accent } else { muted },
          weight: "bold",
        )[#r.clabel],
      )),
      mapping: aes(x: "lx", y: "pope", label: "lab"),
      anchor: "west",
      inherit-aes: false,
    ),
    // Inset parked in the empty right-hand space, clear of the stems and the
    // x-axis labels below.
    annotate("typst", x: 58, y: "Leo XIV", nudge-y: -0.2cm, label: inset, anchor: "south", clip: false),
  ),
  scales: (
    scale-x-continuous(
      name: "Encyclicals Published",
      limits: (0, auto),
      breaks: (0, 20, 40, 60, 80),
      // Flush stems to the axis on the left; keep default padding on the right
      // so the "86" label has room.
      expand: (0%, auto),
    ),
    // Two-line ticks: pope name, then their reign span smaller beneath. The
    // record holder's name carries the accent so the y-axis ties to its stem.
    scale-y-discrete(
      limits: pope-order,
      labels: pope-order.map(p => {
        let m = pope-meta.at(p)
        let end = if m.reign-end == none { "present" } else { str(m.reign-end) }
        let span = str(m.reign-start) + "–" + end
        let name = if p == leo-name { text(fill: accent, weight: "bold")[#p] } else { p }
        [
          #set align(center)
          #name \ #text(size: 6pt)[(#span)]
        ]
      }),
    ),
    // Group palette: muted for every pope, accent reserved for the record holder.
    scale-colour-discrete(limits: ("Other", leo-name), palette: (muted, accent)),
    scale-fill-discrete(limits: ("Other", leo-name), palette: (muted, accent)),
  ),
  // The group split is direct-labelled by colour and the y-axis, so the legend
  // would be redundant.
  guides: guides(default: none),
  labels: labels(
    title: "Leo XIII Outpaced Every Modern Pope: 86 Encyclicals",
    subtitle: [
      Encyclicals per pope since 1878.
      #text(fill: accent, weight: "bold")[Leo XIII] (1878--1903) published more than
      twice Pius XII's 39. \
      The line of popes ran Italian until John Paul II (Poland, 1978); Leo XIV is the first from the United States.
    ],
    caption: typst([
      Source: Papal Encyclicals (TidyTuesday 2026-06-23). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
    x: none,
    y: none,
  ),
  theme: theme-minimal(
    axis-text-y: element-text(size: 8pt),
    tick-length: 0.12cm,
    axis-ticks-y: element-line(),
    axis-ticks-x: element-blank(),
  ),
  width: auto,
  height: auto,
)
