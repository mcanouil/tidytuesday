// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

#let raw = csv("data/papal_encyclicals.csv", row-type: dictionary)

// The data key for the record holder, so the string lives in one place.
#let leo-name = "Leo XIII"

// Count encyclicals per pope and keep each reign span for the y-axis labels.
#let pope-meta = (:)
#for r in raw {
  let p = r.pope
  if p not in pope-meta {
    // Reign years from the pontificate dates. An "NA" end marks a sitting pope.
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

// Leo XIII's 86 encyclicals by year of his reign (1-25). The inset shows that
// his output held across the whole pontificate.
#let leo-counts = (:)
#for r in raw {
  if r.pope != leo-name { continue }
  let y = r.pontificate_year
  leo-counts.insert(y, leo-counts.at(y, default: 0) + 1)
}
#let leo-by-year = range(1, 26).map(y => (yr: y, n: leo-counts.at(str(y), default: 0)))

// Ranking is the message, so the order is by count. The discrete y-axis draws its
// first level at the bottom, so ascending count puts Leo XIII at the top.
#let ranked = pope-meta.pairs().map(pair => {
  (pope: pair.at(0), count: pair.at(1).count)
}).sorted(key: row => row.count)
#let pope-order = ranked.map(row => row.pope)

// The apex of the funnel, read from the data so it pins to the Leo XIII point:
// x just past his count, y at his level.
#let leo-count = pope-meta.at(leo-name).count
#let leo-level = pope-order.position(p => p == leo-name) + 1

// One muted ink for every pope, and one warm accent for the record holder.
#let muted = luma(62%)
#let accent = rgb("#d55e00")
// `x0` anchors each stem at zero and `lx` places the count label past the point
// head. Mapping `nudge-x` instead trips the discrete-scale trainer.
#let rows = ranked.map(row => (
  ..row,
  x0: 0,
  lx: row.count + 2,
  clabel: str(row.count),
  // Two groups, the record holder against everyone else, mapped through colour
  // and fill so one segment layer and one point layer carry the highlight.
  group: if row.pope == leo-name { leo-name } else { "Other" },
))

// Inset: a small column chart of Leo XIII's encyclicals per year of reign, in the
// empty bottom-right. The box reads `page.fill`, so the inset follows the light
// and dark toggle, as the 06/09 inset does.
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
      scales: scales(
        x: scale-continuous(breaks: (1, 5, 10, 15, 20, 25), expand: (0%, 0%)),
        y: scale-continuous(breaks: (0, 4, 8)),
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
        // The stems carry the values, so vertical gridlines only compete.
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
    // The funnel connector, drawn first so the stems, the point, the labels and
    // the inset box sit on top. The box hides the base edge of the triangle.
    geom-polygon(
      data: (
        (x: 34.15, y: 8.374),
        (x: 82.4, y: 0.8),
        (x: leo-count + 0.25, y: leo-level),
      ),
      mapping: aes(x: "x", y: "y"),
      fill: accent,
      stroke: none,
      inherit-aes: false,
    ),
    // The stem length is the count, on a common axis from zero. The group
    // aesthetic tints the record holder and leaves the rest muted.
    geom-segment(
      mapping: aes(x: "x0", y: "pope", xend: "count", yend: "pope", colour: "group"),
      stroke: 1.4pt,
    ),
    geom-point(mapping: aes(fill: "group"), size: 3.4pt),
    // The count sits at the head of each stem, so no reader hunts an axis tick
    // for "86". The record holder's count is bold, to match its stem and tick.
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
    // The inset sits in the empty right-hand space, clear of the stems and the
    // labels below.
    annotate("typst", x: 58, y: "Leo XIV", nudge-y: -0.2cm, label: inset, anchor: "south", clip: false),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Encyclicals Published",
      limits: (0, auto),
      breaks: (0, 20, 40, 60, 80),
      // The stems sit flush to the axis on the left. The right keeps its default
      // padding, so the "86" label has room.
      expand: (0%, auto),
    ),
    // Two-line ticks: the pope's name, then the reign span beneath. The record
    // holder's name carries the accent, so the axis ties to its stem.
    y: scale-discrete(
      limits: pope-order,
      labels: pope-order.map(p => {
        let m = pope-meta.at(p)
        let end = if m.reign-end == none { "present" } else { str(m.reign-end) }
        let span = str(m.reign-start) + "–" + end
        let name = if p == leo-name { text(fill: accent, weight: "bold")[#p] } else { p }
        [
          #set align(center)
          #set par(leading: 0.3em)
          #name \ #text(size: 6pt)[(#span)]
        ]
      }),
    ),
    // Muted for every pope, accent for the record holder.
    colour: scale-discrete(limits: ("Other", leo-name), palette: (muted, accent)),
    fill: scale-discrete(limits: ("Other", leo-name), palette: (muted, accent)),
  ),
  // Colour and the y-axis already label the split, so a legend would repeat it.
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
    axis-ticks-y: element-tick(length: 0.12cm),
  ),
  width: auto,
  height: auto,
)
