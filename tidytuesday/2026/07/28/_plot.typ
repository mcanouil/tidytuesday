// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.4.1": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per biodiversity record: what was seen, where, and when. Every number
// in the chart is derived from this table, so the figure is reproducible end to
// end: no hand-typed counts and no pre-summarised file. The tourism and weather
// tables shipped with the week are left alone; tourism is quarterly, and the
// weather file covers eleven stations against the 183 the records reference.
// Source: data/occurrences.csv (TidyTuesday 2026-07-28).
#let raw = csv("data/occurrences.csv", row-type: dictionary)

// Records carrying no month have no place on a calendar dial, so they are
// dropped; the caption states how many.
#let month-of(v) = if v == none or v == "" or v == "NA" { none } else { int(v) }

// Group a whole number with thousands separators, e.g. 35052 -> "35,052".
#let thousands(n) = {
  let out = ()
  for (i, c) in str(calc.abs(n)).clusters().rev().enumerate() {
    if i > 0 and calc.rem(i, 3) == 0 { out.push(",") }
    out.push(c)
  }
  out.rev().join()
}

#let month-names = (
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
)

// Southern-hemisphere seasons, so a northern reader does not misread July as
// midsummer. Named once here and used for the season ring and the caption.
#let season-of(m) = if m in (12, 1, 2) { "summer" } else if m in (3, 4, 5) {
  "autumn"
} else if m in (6, 7, 8) { "winter" } else { "spring" }

// One pass over the records, tallying each organism's month counts.
#let tally = (:)
#let n-dropped = 0
#for r in raw {
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
// Most records are casual sightings rather than specimens, which is what makes
// the seasonal shape an observation pattern as much as a biological one.
#let n-human = raw.filter(r => r.record_type == "HUMAN_OBSERVATION").len()
#let pct-human = calc.round(100 * n-human / n-records)

// One dial per organism, each scaled to its own records so a species with four
// hundred sightings and one with forty thousand can be read side by side.
// Ordered by how sharply the year concentrates, sharpest first, so the reader
// meets the strongest seasonal signal at the left.
#let dials = tally.pairs().map(((name, counts)) => {
    let total = counts.sum()
    let shares = counts.map(c => 100 * c / total)
    let peak-i = shares.position(s => s == calc.max(..shares))
    (
      organism: name,
      total: total,
      shares: shares,
      peak-month: month-names.at(peak-i),
      peak-share: calc.round(shares.at(peak-i)),
      peak-season: season-of(peak-i + 1),
    )
}).sorted(key: d => d.peak-share).rev()

#let sharpest = dials.first()
#let broadest = dials.last()
// The title spells out "Four", the one count in this figure that is not
// computed, so a fifth organism appearing in the data fails loudly.
#assert(dials.len() == 4, message: "the data no longer holds four organisms")
#let totals = dials.map(d => d.total)
#let smallest-total = calc.min(..totals)
#let largest-total = calc.max(..totals)

// The rings the radial gridlines fall on. Named once here, drawn unlabelled on
// the dials and spelled out in the caption instead, so no number has to sit on
// top of a wedge.
#let rings = (10, 20, 30, 40)
#let ring-list = rings.slice(0, -1).map(str).join(", ") + " and " + str(rings.last())

// The strip carries the panel's own headline, since a facet label is plain text
// and this is the one place a per-panel number can sit without colliding with a
// wedge or a month tick. Faceting on this column instead of the raw name keeps
// the fill scale keyed to the organism.
#let panel-of(d) = d.organism + " · " + str(d.peak-share) + "% " + d.peak-month

// The long table the dials are drawn from: one wedge per organism per month.
#let wedges = ()
#for d in dials {
  for (i, share) in d.shares.enumerate() {
    wedges.push((
      organism: d.organism,
      panel: panel-of(d),
      month: month-names.at(i),
      share: share,
    ))
  }
}

// One hue per organism, each chosen for the thing it names: a rose for the
// orchid, an ochre for the finch's belly, an ocean blue for the ray, and a
// luminous green for the glowworm. Each sits alone in its own dial behind a
// named strip, so identity never rests on colour.
//
// Rose and green are the awkward pair, since a deuteranope reads them as the
// same hue; what separates them is the gap in lightness, which is why the rose
// is held down and the green lifted. All four then clear the colour-vision and
// contrast checks against the pale page and the dark one alike, so the figure
// needs no light/dark branch and nothing outside this file has to tell it which
// page it is on.
#let organism-colours = (
  "Orchid": rgb("#b03e5c"),
  "Gouldian finch": rgb("#c47a12"),
  "Manta ray": rgb("#2f7fc4"),
  "Glowworm": rgb("#3aa270"),
)
// A dark seam rather than a white one: at this opacity it splits neighbouring
// wedges on the pale page without cutting a bright gap in the dark one.
#let wedge-edge = rgb("#3333334d")
#let grid-col = rgb("#8a8f9673") // the rings, the only scale the dials carry
#let dial-order = dials.map(d => d.organism)

// A signage grotesque for the headings and a warm text face for the prose, for
// the feel of a field almanac. Both are vendored in assets/fonts, so CI renders
// them too.
#let body-font = "Lato"
#let chart-font = "Archivo"

// `fill: none` means "say nothing about the colour", so the text inherits the
// page ink typst-render sets and stays legible whichever way the site is
// toggled, rather than pinning a colour that would vanish on the other page.
// Passing a colour is reserved for text that names a coloured mark; secondary
// text steps down in size rather than in colour, for the same reason.
#let inked(fill, ..fields) = {
  let args = fields.named()
  if fill != none { args.insert("fill", fill) }
  args
}
#let note(body, fill: none, size: 7pt, weight: "regular") = text(
  ..inked(fill, font: body-font, size: size, weight: weight),
)[#body]

// Only the four cardinal months are labelled: twelve labels on four dials this
// size collide, and the quarter marks are enough to orient the reader.
//
// They are drawn as a layer rather than as theta ticks, because a radial panel
// puts its tick labels outside the circle and the circle already fills the
// panel, so the built-in ones run off the ends of the figure. Carrying them as
// data instead puts them on the radial scale, which is why that scale is given
// an explicit outer bound with room past the last ring: the labels ride in the
// band between the two, clear of every ring. An explicit `limits:` pins the
// view outright, so the room has to be in the limit rather than in `expand:`.
// Each row names its panel, so every dial gets its own set.
// Both radii hang off the last ring, so moving the rings moves the layout with
// them. The gaps are the smallest that clear the label text at either side:
// every unit spent here shrinks the wedges, and the tallest wedge sitting under
// a labelled month is well short of the tallest wedge overall.
#let shown-months = ("Jan", "Apr", "Jul", "Oct")
#let label-radius = rings.last() + 7 // outside the last ring
#let view-max = label-radius + 5 // the dial's edge, clear of the labels

#let month-labels = ()
#for d in dials {
  for m in shown-months {
    month-labels.push((
      panel: panel-of(d),
      month: m,
      radius: label-radius,
      label: note(size: 6.5pt)[#m],
    ))
  }
}

#plot(
  data: wedges,
  mapping: aes(x: "month", y: "share", fill: "organism"),
  layers: (
    // The rings, drawn as layers rather than as panel grid. A radial panel
    // takes one stroke for the whole grid and spends it on rings and spokes
    // alike, and a spoke runs the full radius straight through the month label
    // sitting on it. Blanking the grid and drawing only the rings keeps the
    // scale and loses the collision.
    ..rings.map(r => geom-hline(
      yintercept: r, stroke: 0.5pt, colour: grid-col, inherit-aes: false,
    )),
    // A full-width wedge per month, so each dial reads as a year rather than as
    // twelve separate bars.
    geom-col(width: 1, colour: wedge-edge, stroke: 0.5pt),
    // The quarter months, in the band between the last ring and the dial edge.
    geom-typst(
      data: month-labels,
      mapping: aes(x: "month", y: "radius", label: "label"),
      inherit-aes: false,
    ),
  ),
  scales: scales(
    x: scale-discrete(limits: month-names, labels: month-names.map(_ => "")),
    // The rings are drawn but not numbered: a figure this size has nowhere to
    // put a radial number that is not already covered by a wedge.
    y: scale-continuous(
      breaks: rings,
      labels: rings.map(_ => ""),
      limits: (0, view-max),
    ),
    fill: scale-discrete(
      limits: dial-order,
      palette: dial-order.map(n => organism-colours.at(n)),
    ),
  ),
  coord: coord-radial(theta: "x"),
  facet: facet-wrap("panel", nrow: 1),
  guides: guides(default: none),
  labels: labels(
    title: "Four Australian Species, Four Different Months",
    // Neither axis carries a title: the rings and the dials are explained in
    // the subtitle and the caption, and the width is better spent on the dials.
    x: none,
    y: none,
    subtitle: [
      Each dial is one species' year, every wedge a month's share of that
      species' own records. The
      #text(fill: organism-colours.at(sharpest.organism), weight: "bold")[#sharpest.organism]
      is the sharpest, with #sharpest.peak-share% of its records falling in
      #sharpest.peak-month alone, while the
      #text(fill: organism-colours.at(broadest.organism), weight: "bold")[#broadest.organism]
      spreads across half the year and peaks at only #broadest.peak-share%.
      Months run clockwise from January, so the southern winter sits at the
      bottom of every dial.
    ],
    caption: typst([
      #thousands(n-used) of #thousands(n-records) records carry a month; #n-dropped have no date and are dropped. Rings mark #ring-list%, and each dial is scaled to its own species (#thousands(smallest-total) to #thousands(largest-total) records). \
      #pct-human% of the records are casual human sightings, so a peak marks when people were out looking as much as when the species was there, and weekends are over-represented in every dial. \
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
    // The rings are drawn as layers instead (see above), so the panel grid is
    // off entirely.
    panel-grid: element-blank(),
    panel-spacing: 0.2cm,
  ),
  width: auto,
  height: auto,
)
