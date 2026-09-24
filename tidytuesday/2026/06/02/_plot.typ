// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// Every EPLP missing sentinel means "no leave", so all of them map to 0. That
// keeps each year at 21 countries and the mean honest.
#let num(s) = if s in ("NA", "Not applicable", "-98", "-99", "") { 0.0 } else {
  float(s)
}

#let raw = csv("data/eplp.csv", row-type: dictionary)

// Each series takes one Okabe-Ito hue, reused by the strokes, the labels and the
// boxes. Insertion order fixes the scale order. Both series share one months
// axis, so the gap between the lines is the story.
#let series-colours = (
  "Mothers": rgb("#0072b2"),
  "Co-parents": rgb("#d55e00"),
)
#let series-scale = scale-discrete(
  limits: series-colours.keys(),
  palette: series-colours.values(),
)

// Maternity leave spans four columns; sum them per country-year.
#let mother-leave(r) = ("mat_m_ld_bb", "mat_m_ld_ab", "mat_v_ld_bb", "mat_v_ld_ab").fold(
  0.0,
  (a, c) => a + num(r.at(c)),
)

// Where each country stands in 2024: one row per country with its mother months,
// its co-parent months and the gap. Sorted so the closest to parity sits at the
// top of the dumbbell.
#let gap-2024 = (
  raw
    .filter(r => float(r.year) == 2024)
    .map(r => {
      let m = mother-leave(r)
      let co = num(r.co_ld)
      // ISO-2 codes to full names for the secondary panel's y axis.
      let name = (
        AT: "Austria", BE: "Belgium", CZ: "Czechia", DE: "Germany", DK: "Denmark",
        EE: "Estonia", ES: "Spain", FI: "Finland", FR: "France", GR: "Greece",
        HU: "Hungary", IE: "Ireland", IT: "Italy", LT: "Lithuania", NL: "Netherlands",
        NO: "Norway", PL: "Poland", SE: "Sweden", SI: "Slovenia", SK: "Slovakia",
        UK: "United Kingdom",
      ).at(r.country, default: r.country)
      (country: name, mother: m, coparent: co, spread: m - co)
    })
    .sorted(key: row => row.at("spread"))
)

#compose(
  defer(
    plot,
    // Long format, one row per country, year and series. The layers take the
    // mean through stat-summary.
    data: raw
      .map(r => (
        (year: float(r.year), series: "Mothers", months: mother-leave(r)),
        (year: float(r.year), series: "Co-parents", months: num(r.co_ld)),
      ))
      .flatten(),
    mapping: aes(x: "year", y: "months", colour: "series"),
    layers: (
      // A one standard-error band per series, from stat-summary(mean-se), drawn
      // first so it sits under the line. `fill: "series"` gives it the line hue.
      geom-ribbon(
        mapping: aes(fill: "series"),
        stat: stat-summary(fun: "mean-se", axis: "y"),
        alpha: 0.2,
      ),
      // The per-year mean line. stat-summary buckets each series by year.
      geom-line(stroke: 1.6pt, stat: stat-summary(fun: "mean", axis: "y")),
      // Direct labels rather than a legend: the series name at a hand-placed point,
      // coloured through the shared scale.
      geom-typst(
        data: (
          (year: 1983, months: 19.4, series: "Mothers", label: "*Mothers*"),
          (year: 2010, months: 0.75, series: "Co-parents", label: "*Co-parents*"),
        ),
        mapping: aes(label: "label"),
        anchor: "west",
      ),
      // End-value labels. `data` filters the inherited frame to the final year and
      // stat-summary takes its mean, as the line does. `after-stat` binds the text
      // to that same value, so the number cannot drift from the line.
      geom-label(
        data: d => d.filter(o => o.year == 2024),
        mapping: aes(
          fill: "series",
          label: after-stat((row, ctx) => str(calc.round(row.y)) + " months"),
          nudge-y: 1,
        ),
        stat: stat-summary(fun: "mean", axis: "y"),
        size: 9pt,
        colour: white,
        segment: true,
      ),
      // Callout in the empty wedge between the lines. The box background reads
      // `page.fill`, so it follows the light and dark toggle.
      annotate(
        "typst",
        x: 1977,
        y: 9,
        label: context box(
          fill: if page.fill in (auto, none) { white } else { page.fill },
          inset: (x: 5pt, y: 4pt),
          radius: 3pt,
          stroke: 0.5pt + rgb("#0f8b8d"),
        )[
          Leave reserved for the
          #text(fill: series-colours.at("Co-parents"), weight: "semibold")[co-parent] \
          barely existed until 2000. \
          *4* countries offered it in *1980*; *19* do in *2024*.
        ],
        size: 8pt,
        anchor: "west",
      ),
    ),
    scales: scales(
      x: scale-continuous(
        breaks: (1970, 1980, 1990, 2000, 2010, 2024),
        expand: (1%, 10%),
      ),
      y: scale-continuous(limits: (0, 24)),
      colour: series-scale,
      fill: series-scale,
    ),
    guides: guides(colour: none, fill: none),
    labels: labels(x: none, y: "Months of Leave"),
    theme: theme-minimal(),
  ),
  // Second panel: a 2024 snapshot of all 21 countries as a dumbbell. A grey
  // segment runs from the mother dot to the co-parent dot, so its length is the
  // gap, and parity sits at the top. Months by country is a different question
  // from the time series, and colour still means series, which ties the two
  // panels together.
  defer(
    plot,
    // The two dots per country, in long format, coloured by series as on the
    // main panel.
    data: gap-2024
      .map(row => (
        (country: row.country, series: "Mothers", months: row.mother),
        (country: row.country, series: "Co-parents", months: row.coparent),
      ))
      .flatten(),
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
    scales: scales(
      x: scale-continuous(limits: (0, 44), breaks: (0, 12, 24, 36)),
      // `gap-2024` is sorted parity first, and the discrete axis draws its first
      // level at the bottom, so the order is reversed here.
      y: scale-discrete(limits: gap-2024.map(row => row.country).rev()),
      fill: series-scale,
    ),
    guides: guides(fill: none),
    labels: labels(x: "Months of Leave", y: none),
    theme: theme-minimal(
      axis-text-y: element-text(font: "DejaVu Sans Mono", size: 7pt),
      axis-ticks-y: element-tick(length: 0.08cm),
    ),
  ),
  columns: 2,
  widths: (1.4, 1),
  width: auto,
  height: auto,
  tag-levels: "A",
  tag-prefix: "(",
  tag-suffix: ")",
  align-panels: true,
  labels: labels(
    title: "Europe Still Reserves Far More Leave for Mothers Than for the Co-Parent",
    subtitle: [*(A)* the gap between #text(fill: series-colours.at("Mothers"), weight: "bold")[mothers] and the #text(fill: series-colours.at("Co-parents"), weight: "bold")[co-parent] has narrowed since 2000 yet mothers still get far more; \ *(B)* in 2024 it ranges from parity (Spain, Slovakia, UK) to roughly 40 months (Ireland).],
    caption: typst([
      Source: European Parenting Leave Policies (TidyTuesday 2026-06-02). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
)
