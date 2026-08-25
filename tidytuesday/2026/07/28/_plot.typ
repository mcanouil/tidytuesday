// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per biodiversity record: what was seen, where, and when. Every number
// in the chart comes from this table. The tourism table is quarterly and the
// weather file covers eleven stations against 183, so both are left alone.
// Source: data/occurrences.csv (TidyTuesday 2026-07-28).
#let raw = csv("data/occurrences.csv", row-type: dictionary)

// A record with no month has no place on a dial, so it is dropped. The caption
// states how many.
#let month-of(v) = if v == none or v == "" or v == "NA" { none } else { int(v) }
#let comma = format-comma()
#let pct = format-percent()

#let month-names = (
  "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.",
  "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec.",
)

// One pass over the forty thousand records: monthly counts per organism, and the
// share that are casual sightings rather than specimens.
#let tally = (:)
#let n-dropped = 0
#let n-human = 0
#for r in raw {
  if r.record_type == "HUMAN_OBSERVATION" { n-human += 1 }
  let m = month-of(r.month)
  if m == none {
    n-dropped += 1
    continue
  }
  let counts = tally.at(r.organism_name, default: (0,) * 12)
  counts.at(m - 1) += 1
  tally.insert(r.organism_name, counts)
}

#let n-records = raw.len()
#let n-used = n-records - n-dropped
#let pct-human = pct(n-human / n-records)

// One dial per organism, each scaled to its own records, so four hundred
// sightings and forty thousand can be read side by side. Ordered by how sharply
// the year concentrates, sharpest first.
#let dials = tally.pairs().map(((name, counts)) => {
  let total = counts.sum()
  let shares = counts.map(c => c / total)
  let peak = calc.max(..shares)
  let peak-i = shares.position(s => s == peak)
  (
    organism: name,
    total: total,
    shares: shares.map(s => 100 * s),
    peak: peak,
    peak-month: month-names.at(peak-i),
    peak-share: pct(peak),
  )
}).sorted(key: d => d.peak).rev()

#let sharpest = dials.first()
#let broadest = dials.last()
// The title spells out "Four", the one count not computed, so a fifth organism
// fails the render.
#assert(dials.len() == 4, message: "the data no longer holds four organisms")
#let totals = dials.map(d => d.total)
#let smallest-total = calc.min(..totals)
#let largest-total = calc.max(..totals)

// The rings the radial gridlines fall on. Drawn unlabelled and spelled out in
// the caption, so no number sits on a wedge. The outer bound clears the tallest.
#let rings = (10, 20, 30, 40)
#let ring-list = rings.slice(0, -1).map(str).join(", ") + " and " + str(rings.last())
#let ring-max = 45

// The long table the dials are drawn from: one wedge per organism per month.
//
// The strip carries each panel's headline, since a facet label is plain text and
// this is the one place a per-panel number fits. Faceting on that string keeps
// the fill scale keyed to the organism.
#let wedges = ()
#for d in dials {
  let panel = d.organism + " · " + d.peak-share + " " + d.peak-month
  for (i, share) in d.shares.enumerate() {
    wedges.push((
      organism: d.organism,
      panel: panel,
      month: month-names.at(i),
      share: share,
    ))
  }
}

// One hue per organism, named for what it describes. Rose and green read alike to
// a deuteranope, so the rose is held down and the green lifted: lightness is what
// separates them. All four clear the checks on both surfaces.
#let organism-colours = (
  "Orchid": rgb("#b03e5c"),
  "Gouldian finch": rgb("#c47a12"),
  "Manta ray": rgb("#2f7fc4"),
  "Glowworm": rgb("#3aa270"),
)
// A dark seam rather than a white one: it splits neighbouring wedges on the pale
// page without cutting a bright gap in the dark one.
#let wedge-edge = rgb("#3333334d")
#let grid-col = rgb("#8a8f9673") // the rings, the only scale the dials carry
#let dial-order = dials.map(d => d.organism)

// A grotesque for the headings and a text face for the prose, for the feel of a
// field almanac. Both are vendored in assets/fonts, so CI renders them too.
#let body-font = "Lato"
#let chart-font = "Archivo"

#plot(
  data: wedges,
  mapping: aes(x: "month", y: "share", fill: "organism"),
  layers: (
    // A full-width wedge per month, so each dial reads as a year.
    geom-col(width: 1, colour: wedge-edge, stroke: 0.5pt),
  ),
  scales: scales(
    // Only the quarter months are labelled: twelve labels on dials this size
    // collide. The rest keep their tick.
    x: scale-discrete(
      limits: month-names,
      labels: month-names.map(m => if m in ("Jan.", "Apr.", "Jul.", "Oct.") { m } else { "" }),
      expand: false,
    ),
    y: scale-continuous(breaks: rings, limits: (0, ring-max)),
    fill: scale-discrete(
      limits: dial-order,
      palette: dial-order.map(n => organism-colours.at(n)),
    ),
  ),
  coord: coord-radial(theta: "x"),
  facet: facet-wrap("panel", nrow: 1),
  // The rings stay, their numbers go: there is nowhere to put a radial number
  // that a wedge does not cover. `default` never reaches the radial axis, so `r`
  // says so itself.
  guides: guides(default: none, r: none),
  labels: labels(
    title: "Four Australian Species, Four Different Months",
    // Neither axis carries a title: the subtitle and the caption explain the
    // rings, and the width is better spent on the dials.
    x: none,
    y: none,
    subtitle: [
      Each dial is one species' year, every wedge a month's share of that species' own records.
      The #text(fill: organism-colours.at(sharpest.organism), weight: "bold")[#sharpest.organism] is the sharpest, with #sharpest.peak-share of its records falling in
      #text(style: "italic")[#sharpest.peak-month] alone, while the #text(fill: organism-colours.at(broadest.organism), weight: "bold")[#broadest.organism]
      spreads across half the year and peaks at only #broadest.peak-share.
      Months run clockwise from January, so the southern winter sits at the bottom of every dial.
    ],
    caption: typst([
      #comma(n-used) of #comma(n-records) records carry a month; #n-dropped have no date and are dropped. Rings mark #ring-list%, and each dial is scaled to its own species (#comma(smallest-total) to #comma(largest-total) records). \
      #pct-human of the records are casual human sightings, so a peak marks when people were out looking as much as when the species was there, and weekends are over-represented in every dial. \
      Source: Australian biodiversity occurrences (TidyTuesday 2026-07-28). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7pt),
    strip-background: element-blank(),
    strip-text: element-text(font: chart-font, size: 8.5pt, weight: "bold"),
    // Rings and spokes share this stroke, and both stop inside the month labels.
    panel-grid: element-line(colour: grid-col),
    panel-spacing: 0.5cm,
    panel-background: element-rect(
      fill: rgb("#f7f0e7"),
      outset: margin(top: 0.4cm, right: 0.4cm, bottom: 0.4cm, left: 0.4cm),
    )
  ),
  width: auto,
  height: auto,
)
