// Gribouille comes from the typst-render preamble; do not re-import (rebinds the
// theme-* wrappers).
// #import "@preview/gribouille:0.2.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// EPLP missing sentinels all mean "no leave", so map them to 0; this keeps every
// year balanced at 21 countries for an honest mean.
#let num(s) = if s in ("NA", "Not applicable", "-98", "-99", "") { 0.0 } else {
  float(s)
}

#let raw = csv("data/eplp.csv", row-type: dictionary)

// Each series bound to one Okabe-Ito hue (colourblind-safe), reused by strokes,
// labels, and boxes; insertion order fixes the scale order. Both series share one
// months axis so the gap between the lines is the story (Wilke).
#let series-colours = (
  "Mothers": rgb("#0072b2"),
  "Co-parents": rgb("#d55e00"),
)
#let series = series-colours.keys()

// Boxed callout that lifts prose off the lines. Background reads the ambient
// `page.fill`, so the box tracks the light / dark site toggle.
#let accent = rgb("#0f8b8d")
#let callout(body) = context {
  let bg = if page.fill in (auto, none) { white } else { page.fill }
  box(
    fill: bg,
    inset: (x: 5pt, y: 4pt),
    radius: 3pt,
    stroke: 0.5pt + accent,
  )[#body]
}

// Maternity leave spans four columns; sum them per country-year.
#let mat-cols = ("mat_m_ld_bb", "mat_m_ld_ab", "mat_v_ld_bb", "mat_v_ld_ab")
#let mother-leave(r) = mat-cols.fold(0.0, (a, c) => a + num(r.at(c)))

// Long format, one row per country x year x series; the layers mean these via
// stat-summary.
#let obs = {
  let acc = ()
  for r in raw {
    let y = float(r.year)
    acc.push((year: y, series: "Mothers", months: mother-leave(r)))
    acc.push((year: y, series: "Co-parents", months: num(r.co_ld)))
  }
  acc
}

// ISO-2 codes to full names for the secondary panel's y axis.
#let country-names = (
  AT: "Austria", BE: "Belgium", CZ: "Czechia", DE: "Germany", DK: "Denmark",
  EE: "Estonia", ES: "Spain", FI: "Finland", FR: "France", GR: "Greece",
  HU: "Hungary", IE: "Ireland", IT: "Italy", LT: "Lithuania", NL: "Netherlands",
  NO: "Norway", PL: "Poland", SE: "Sweden", SI: "Slovenia", SK: "Slovakia",
  UK: "United Kingdom",
)

// Secondary panel data: where each country stands in 2024. One row per country
// with its mother and co-parent months and the gap between them, sorted so the
// closest-to-parity sits at the top of the dumbbell.
#let gap-2024 = (
  raw
    .filter(r => float(r.year) == 2024)
    .map(r => {
      let m = mother-leave(r)
      let co = num(r.co_ld)
      let name = country-names.at(r.country, default: r.country)
      (country: name, mother: m, coparent: co, spread: m - co)
    })
    .sorted(key: row => row.at("spread"))
)

// y order for the discrete country axis. gap-2024 is sorted parity-first; the
// discrete y axis draws its first level at the bottom, so reverse to put parity
// (smallest gap) at the top of the dumbbell.
#let country-order = gap-2024.map(row => row.country).rev()

// The two dots per country, long format, coloured by series like the main panel.
#let gap-dots = {
  let acc = ()
  for row in gap-2024 {
    acc.push((country: row.country, series: "Mothers", months: row.mother))
    acc.push((country: row.country, series: "Co-parents", months: row.coparent))
  }
  acc
}

#let main = defer(
  plot,
  data: obs,
  mapping: aes(x: "year", y: "months", colour: "series"),
  layers: (
    // +/-1 SE band per series via stat-summary(mean-se); drawn first so it sits
    // under the line. fill: "series" tints it in each line's hue.
    geom-ribbon(
      mapping: aes(fill: "series"),
      stat: stat-summary(fun: "mean-se", axis: "y"),
      alpha: 0.2,
    ),
    // Per-year mean line: stat-summary buckets each series by year, fun: "mean".
    geom-line(stroke: 1.6pt, stat: stat-summary(fun: "mean", axis: "y")),
    // Direct labels instead of a legend: bold series name at a hand-placed point,
    // coloured by series via the shared scale.
    geom-typst(
      data: (
        (year: 1983, months: 19.4, series: "Mothers", label: "*Mothers*"),
        (year: 2010, months: 0.75, series: "Co-parents", label: "*Co-parents*"),
      ),
      mapping: aes(x: "year", y: "months", label: "label", colour: "series"),
      anchor: "west",
      inherit-aes: false,
    ),
    // End-value labels: `data` filters the inherited frame to the final year, then
    // stat-summary means it like the line; the box sits at that mean and after-stat
    // binds its text to the same value, so the number can never drift from the line.
    geom-label(
      data: d => d.filter(o => o.year == 2024),
      mapping: aes(
        x: "year",
        y: "months",
        fill: "series",
        label: after-stat((row, ctx) => str(calc.round(row.y)) + " months"),
      ),
      stat: stat-summary(fun: "mean", axis: "y"),
      size: 9pt,
      colour: white,
      dx: 0,
      dy: 1,
      segment: true,
      inherit-aes: false,
    ),
    // Callout in the empty wedge between the lines.
    annotate(
      "typst",
      x: 1977,
      y: 9,
      label: callout[
        Leave reserved for the
        #text(fill: series-colours.at("Co-parents"), weight: "semibold")[co-parent] \
        barely existed until 2000. \
        *4* countries offered it in *1980*; *19* do in *2024*.
      ],
      size: 8pt,
      anchor: "west",
    ),
  ),
  scales: (
    scale-x-continuous(
      breaks: (1970, 1980, 1990, 2000, 2010, 2024),
      expand: (1%, 10%),
    ),
    scale-y-continuous(limits: (0, 24)),
    scale-colour-discrete(
      limits: series,
      palette: series-colours.values(),
    ),
    scale-fill-discrete(
      limits: series,
      palette: series-colours.values(),
    ),
  ),
  guides: guides(colour: guide-none(), fill: guide-none()),
  labs: labs(x: none, y: "Months of Leave"),
  theme: theme-minimal(),
)

// Secondary panel: a 2024 snapshot of all 21 countries as a dumbbell. A grey
// segment per country spans its mother dot to its co-parent dot, so the bar
// length IS the gap; sorted with parity at the top. Different axes (months by
// country) make this read as a different question from the time series, not a
// lookalike. Colour still means series, tying it to the main panel.
#let secondary = defer(
  plot,
  data: gap-dots,
  mapping: aes(x: "months", y: "country", fill: "series"),
  layers: (
    geom-segment(
      data: gap-2024,
      mapping: aes(x: "coparent", y: "country", xend: "mother", yend: "country"),
      stroke: 2pt,
      colour: luma(70%),
      inherit-aes: false,
    ),
    geom-point(size: 3.4pt, alpha: 0.5),
  ),
  scales: (
    scale-x-continuous(limits: (0, 44), breaks: (0, 12, 24, 36)),
    scale-y-discrete(limits: country-order),
    scale-fill-discrete(limits: series, palette: series-colours.values()),
  ),
  guides: guides(fill: guide-none()),
  labs: labs(x: "Months of Leave", y: none),
  theme: theme-minimal(
    axis-text-y: element-text(font: "DejaVu Sans Mono", size: 7pt),
    tick-length-y: 0.08cm,
  ),
)

#compose(
  main,
  secondary,
  columns: 2,
  widths: (1.4, 1),
  tag-levels: "A",
  tag-prefix: "(",
  tag-suffix: ")",
  align-panels: true,
  labs: labs(
    title: "Europe Still Reserves Far More Leave for Mothers Than for the Co-Parent",
    subtitle: [*(A)* the gap between #text(fill: series-colours.at("Mothers"), weight: "bold")[mothers] and the #text(fill: series-colours.at("Co-parents"), weight: "bold")[co-parent] has narrowed since 2000 yet mothers still get far more; \ *(B)* in 2024 it ranges from parity (Spain, Slovakia, UK) to roughly 40 months (Ireland).],
    caption: typst([
      Source: European Parenting Leave Policies (TidyTuesday 2026-06-02). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
)
