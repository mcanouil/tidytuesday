// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per test type, nationality, band and year, holding the share of that
// group at that band. Each group sums to 1, so a small country counts as much
// as a large one.
// Source: data/demo_by_nationality.csv (TidyTuesday 2026-08-18).
#let raw = csv("data/demo_by_nationality.csv", row-type: dictionary)

#let pct0 = format-percent(digits: 0)
#let pct1 = format-percent(digits: 1)
#let dp2 = format-number(digits: 2)

// The Academic paper, in the most recent year. General Training is a different
// test with different candidates.
#let test-type = "Academic"
#let test-year = "2024-2025"

// The twelve reported bands, lowest first. Everything under 4 arrives in one
// open bucket.
#let band-order = ("<4", "4", "4.5", "5", "5.5", "6", "6.5", "7", "7.5", "8", "8.5", "9")

// Each band sits at its own score, so the vertical axis is the band scale. The
// open bucket has no score of its own and is drawn at 3.5. Every mean here
// leans on that choice, and the caption says so.
#let band-score = (
  "<4": 3.5,
  "4": 4.0,
  "4.5": 4.5,
  "5": 5.0,
  "5.5": 5.5,
  "6": 6.0,
  "6.5": 6.5,
  "7": 7.0,
  "7.5": 7.5,
  "8": 8.0,
  "8.5": 8.5,
  "9": 9.0,
)

// Four names are too long for a column 0.28 cm wide. Only the label changes.
#let short-name = (
  "United Arab Emirates": "UAE",
  "Korea, Republic of": "South Korea",
  "Iran, Islamic Republic of": "Iran",
  "Russian Federation": "Russia",
)
#let label-of(nat) = short-name.at(nat, default: nat)

// The band most universities ask for. It falls between the 6 and 6.5 tiles, so
// the rule is drawn at 6.25.
#let requirement = 6.5
#let requirement-rule = 6.25

#let by-nat = (:)
#for r in raw {
  if r.type != test-type or r.year != test-year { continue }
  let entry = by-nat.at(r.nationality, default: (:))
  entry.insert(r.band, float(r.percent))
  by-nat.insert(r.nationality, entry)
}

// Every nationality reports all twelve bands, so no share is inferred.
#for (nat, bands) in by-nat {
  assert(
    bands.len() == band-order.len(),
    message: "nationality " + nat + " is missing a band",
  )
  assert(
    calc.abs(bands.values().sum() - 1) < 0.001,
    message: "the shares for " + nat + " do not sum to one",
  )
}

#let mass-from(bands, floor) = {
  band-order.filter(b => band-score.at(b) >= floor).map(b => bands.at(b)).sum()
}

#let summarise-nat(nat, bands) = {
  let mean = band-order.map(b => band-score.at(b) * bands.at(b)).sum()
  let variance = band-order.map(b => bands.at(b) * calc.pow(band-score.at(b) - mean, 2)).sum()
  (
    nationality: nat,
    mean: mean,
    sd: calc.sqrt(variance),
    clears: mass-from(bands, requirement),
    below: 1 - mass-from(bands, 5.5),
  )
}

#let summary = by-nat.pairs().map(p => summarise-nat(p.first(), p.last()))
#let ordered = summary.sorted(key: s => s.mean)
#let nat-order = ordered.map(s => s.nationality)

// The claim the order rests on: a higher mean band comes with a tighter spread.
// It is measured here, so a change upstream fails the render.
#let correlation(xs, ys) = {
  let n = xs.len()
  let mx = xs.sum() / n
  let my = ys.sum() / n
  let dx = xs.map(x => x - mx)
  let dy = ys.map(y => y - my)
  let cov = range(n).map(i => dx.at(i) * dy.at(i)).sum()
  cov / calc.sqrt(dx.map(d => d * d).sum() * dy.map(d => d * d).sum())
}
#let spread-corr = correlation(ordered.map(s => s.mean), ordered.map(s => s.sd))
#assert(
  spread-corr < -0.3,
  message: "spread no longer narrows as the mean band rises",
)

// The pair the right panel draws: two nationalities with the same mean band and
// a different shape around it. Found in the data, not hand-picked.
#let closest-pair = {
  let best = none
  for (i, a) in ordered.enumerate() {
    for b in ordered.slice(i + 1) {
      if calc.abs(a.mean - b.mean) > 0.005 { continue }
      let apart = calc.abs(a.sd - b.sd)
      if best == none or apart > best.apart {
        best = (
          low: if a.sd < b.sd { a } else { b },
          high: if a.sd < b.sd { b } else { a },
          apart: apart,
        )
      }
    }
  }
  best
}
#assert(
  closest-pair != none and closest-pair.apart > 0.2,
  message: "no two nationalities share a mean band and differ in spread",
)

#let tight = closest-pair.low
#let wide = closest-pair.high
#let pair-order = (wide.nationality, tight.nationality)

// One tile per nationality and band: forty columns of twelve.
#let tiles = ()
#for (nat, bands) in by-nat {
  for b in band-order {
    tiles.push((
      nationality: label-of(nat),
      score: band-score.at(b),
      share: bands.at(b),
    ))
  }
}

// The two profiles, in band order, so the path joins neighbouring bands.
#let profiles = ()
#for nat in pair-order {
  for b in band-order {
    profiles.push((
      nationality: nat,
      score: band-score.at(b),
      share: by-nat.at(nat).at(b),
    ))
  }
}

#let peak-share = tiles.map(t => t.share).fold(0, calc.max)

// Where the fill ramp stops, and how many tiles sit above it.
#let fill-ceiling = 0.20
#let saturated = tiles.filter(t => t.share > fill-ceiling).len()

// Ink, paper and rules come from the theme that typst-render resolved, so they
// follow the light and dark toggle of the site.
#let ink = theme-minimal().at("ink", default: black)
#let paper-colour = theme-minimal().at("paper", default: white)
#let rule-colour = ink.transparentize(30%)
#let note-colour = ink.transparentize(20%)

// A grotesque for the headings and a text face for the prose. Both are vendored
// in assets/fonts, so CI renders them too.
#let body-font = "Lato"
#let chart-font = "Archivo"

// Blue against amber is the strongest pair on both surfaces: a worst-case
// colour-vision distance of 23.2, and both clear the 3:1 contrast floor. Shape
// and the names in the subtitle repeat what the colour says.
#let pair-colours = (
  (wide.nationality): rgb("#c47a12"),
  (tight.nationality): rgb("#2f7fc4"),
)
#let pair-shapes = (
  (wide.nationality): "circle",
  (tight.nationality): "square",
)

#let pair-scale = scale-discrete(
  limits: pair-order,
  palette: pair-order.map(n => pair-colours.at(n)),
  labels: pair-order.map(label-of),
)
#let shape-scale = scale-manual(
  limits: pair-order,
  values: pair-order.map(n => pair-shapes.at(n)),
  labels: pair-order.map(label-of),
)

#let note(body) = text(font: body-font, size: 6.5pt, fill: note-colour)[#body]

// The two nationalities wear their colour wherever they are named: in the
// subtitle, and under their own column.
#let axis-label(nat) = if nat in pair-order {
  box(text(fill: pair-colours.at(nat), weight: "bold")[#label-of(nat)])
} else {
  label-of(nat)
}
#let coloured(name) = box(text(fill: pair-colours.at(name), weight: "bold")[#label-of(name)])

#let panel-theme = theme-minimal(
  legend-background: element-rect(fill: paper-colour),
  axis-title: element-text(font: body-font, size: 8pt),
  axis-text: element-text(font: body-font, size: 5.5pt),
  legend-text: element-text(font: body-font, size: 7pt),
  legend-title: element-text(font: body-font, size: 7pt),
  axis-ticks: element-tick(length: 0.05cm),
  // Nothing is read off a fraction of a band, so the minor rules do no work.
  panel-grid-minor-x: element-blank(),
  panel-grid-minor-y: element-blank(),
)

// Both panels use the same band scale, so one height means the same on each.
#let band-scale = scale-continuous(
  limits: (3.2, 9.3),
  breaks: (3.5, 4, 5, 6, 7, 8, 9),
  labels: ("<4", "4", "5", "6", "7", "8", "9"),
  expand: (0%, 0%),
)

// One ramp for both panels. `compose` lifts a key out of the panels only when
// every panel carries it, so both declare this scale.
// The hue is green, away from the amber and blue that carry identity. It clears
// the chroma floor and the 3:1 contrast floor on both surfaces, and stands 17.7
// from the blue for a reader with full colour vision.
#let share-scale = scale-gradient(
  low: paper-colour,
  high: rgb("#2f7d52"),
  // Most tiles sit under a tenth. The ramp stops at `fill-ceiling` so the panel
  // is not pale throughout, and heavier tiles take the darkest step.
  limits: (0, fill-ceiling),
  oob: "squish",
  breaks: (0, 0.05, 0.1, 0.15, 0.2),
  labels: pct0,
)

// Left panel: one column of twelve tiles per nationality, ordered by mean band.
// The mass climbs and tightens, which is what the correlation counts.
#let heat-panel = defer(
  plot,
  data: tiles,
  mapping: aes(x: "nationality", y: "score", fill: "share"),
  layers: (
    geom-tile(width: 0.82, height: 0.42),
    geom-hline(
      yintercept: requirement-rule,
      colour: rule-colour,
      stroke: 0.7pt,
      linetype: "dashed",
    ),
  ),
  scales: scales(
    x: scale-discrete(
      limits: nat-order.map(label-of),
      labels: nat-order.map(axis-label),
      expand: (1.5%, 1.5%),
    ),
    y: band-scale,
    fill: share-scale,
  ),
  guides: guides(x: guide-axis(angle: 60)),
  labels: labels(
    x: none,
    y: "Overall band",
    fill: "Share of candidates",
  ),
  theme: panel-theme,
  width: 11.6cm,
  height: 8.2cm,
)

// Right panel: the two nationalities with the same mean band. Profiles rather
// than columns, because the shape of one curve against the other is the point.
#let profile-panel = defer(
  plot,
  data: profiles,
  // The markers carry the share twice: in position and in fill. That gives this
  // panel the same key as the one beside it, which is what `compose` lifts out.
  // The ring keeps the nationality.
  mapping: aes(
    x: "share",
    y: "score",
    colour: "nationality",
    shape: "nationality",
    fill: "share",
  ),
  layers: (
    geom-hline(
      yintercept: requirement-rule,
      colour: rule-colour,
      stroke: 0.7pt,
      linetype: "dashed",
    ),
    geom-path(stroke: 1pt),
    geom-point(size: 2.4pt, stroke: 0.8pt),
    annotate(
      "segment",
      x: 0.17,
      xend: 0.085,
      y: 4.3,
      yend: 4.7,
      stroke: 0.6pt + note-colour,
      arrow: arrow(length: 4pt),
      clip: false,
    ),
    annotate(
      "typst",
      x: 0.175,
      y: 4.25,
      label: note[
        #pct1(wide.below) of #label-of(wide.nationality) \
        sit below 5.5, against \
        #pct1(tight.below) of #label-of(tight.nationality)
      ],
      anchor: "west",
      clip: false,
    ),
  ),
  scales: scales(
    x: scale-continuous(breaks: (0, 0.1, 0.2, 0.3), labels: pct0, expand: (4%, 4%)),
    y: band-scale,
    colour: pair-scale,
    shape: shape-scale,
    fill: share-scale,
  ),
  // No key here. The subtitle and the note name both nationalities, so the ramp
  // stays the only legend.
  guides: guides(default: none),
  labels: labels(
    x: "Share of candidates",
    y: none,
    colour: none,
    shape: none,
    fill: "Share of candidates",
  ),
  theme: panel-theme,
  width: 5.5cm,
  height: 8.2cm,
)

#compose(
  heat-panel,
  profile-panel,
  columns: 2,
  widths: (2, 1),
  gutter: 0.2cm,
  // The panels share the band scale, so they share plot margins too. The ramp is
  // lifted out of them into one key on the right.
  align-panels: true,
  collect: ("fill",),
  guides: guides(default: guide-legend(position: "right", key-size: 0.3cm)),
  labels: labels(
    title: "Two Countries, One Average, Different Fates",
    subtitle: [
      Overall IELTS #lower(test-type) bands, #test-year: one column per nationality, one tile per band, ordered by mean band, with the dashed rule at band #requirement, the usual university requirement.
      The mass climbs and tightens together, so the higher the mean the narrower the spread (correlation #sym.minus#dp2(calc.abs(spread-corr)) across the #nat-order.len()).
      #coloured(wide.nationality) and #coloured(tight.nationality) share a mean of #dp2(tight.mean), and yet #pct1(tight.clears) of #label-of(tight.nationality) clear #requirement against #pct1(wide.clears) of #label-of(wide.nationality).
    ],
    caption: typst([
      Shares are of each nationality's own candidates, so one with few of them counts as much as one with many; the data carries no candidate counts. \
      The fill ramp tops out at #pct0(fill-ceiling)#[;] #saturated of the #tiles.len() tiles carry more than that and are drawn at the darkest step, the heaviest being #pct1(peak-share). \
      Bands below 4 are reported as one open bucket, drawn and averaged at 3.5, half a band below 4, so every mean here leans on that choice. \
      Source: IELTS test taker performance (TidyTuesday 2026-08-18). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
  ),
  width: 18cm,
  height: 9.45cm,
)
