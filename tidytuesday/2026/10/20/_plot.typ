// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it. keisen is imported as a module, because a
// star import clashes with Gribouille (theme-minimal, format-number and
// format-percent exist in both).
#import "@local/keisen:0.0.0" as keisen

// One row per college major. `ai_exposure` is the mean AI exposure of the
// occupations a major leads to, `ai_exposure_percentile` ranks it from 0 to 100
// across the 285 majors, and `median_starting_salary` is in US dollars.
// Source: data/ai_salary_majors.csv (TidyTuesday 2026-10-20).
#let raw-majors = csv("data/ai_salary_majors.csv", row-type: dictionary)
#assert(
  raw-majors.all(m => (
    ("median_starting_salary", "ai_exposure_percentile", "ai_exposure").all(k => m.at(k, default: "") not in ("", "NA"))
  )),
  message: "a major in data/ai_salary_majors.csv has a missing median_starting_salary, ai_exposure_percentile or ai_exposure; fix or drop the row",
)
#let majors = raw-majors.map(m => (
  field: m.broad_field_short,
  salary: float(m.median_starting_salary),
  pct: float(m.ai_exposure_percentile),
  exposure: float(m.ai_exposure),
))

#let median(values) = {
  let v = values.sorted()
  let n = v.len()
  let h = calc.quo(n, 2)
  if calc.odd(n) { v.at(h) } else { (v.at(h - 1) + v.at(h)) / 2 }
}

// Fields with 8 or more majors, lowest median exposure first. Ties keep the
// alphabetical order of the field name.
#let min-majors = 8
#let fields = {
  let names = majors.map(m => m.field).dedup()
  names
    .map(f => {
      let ms = majors.filter(m => m.field == f)
      (name: f, n: ms.len(), med: median(ms.map(m => m.pct)), majors: ms.sorted(key: m => m.salary))
    })
    .filter(f => f.n >= min-majors)
    .sorted(key: f => (f.med, f.name))
}

#let all-median = median(majors.map(m => m.salary))

// Pearson correlation of exposure and starting salary.
#let correlation(ms) = {
  let n = ms.len()
  let mx = ms.map(m => m.exposure).sum() / n
  let my = ms.map(m => m.salary).sum() / n
  let sxy = ms.map(m => (m.exposure - mx) * (m.salary - my)).sum()
  let sxx = ms.map(m => calc.pow(m.exposure - mx, 2)).sum()
  let syy = ms.map(m => calc.pow(m.salary - my, 2)).sum()
  sxy / calc.sqrt(sxx * syy)
}
#let r = correlation(majors)

#assert(majors.len() == 285, message: "the major count changed")
#assert(fields.len() == 14, message: "fields with 8 or more majors changed")
#assert(all-median == 41189, message: "the all-majors median salary changed")
#assert(calc.abs(r) < 0.02, message: "salary and exposure are now correlated")
#assert(calc.round(r, digits: 3) == 0.005, message: "the printed correlation changed")
#assert(
  fields.map(f => f.name)
    == (
      "Engineering Tech", "Agriculture", "Health Professions", "Visual & Performing Arts", "Biological Sciences",
      "Engineering", "Architecture", "Education", "Business", "Computer Science", "Physical Sciences",
      "Social Sciences", "Foreign Languages", "Interdisciplinary",
    ),
  message: "the order of the fields changed",
)
#assert(
  fields.map(f => calc.floor(f.med + 0.5))
    == (14, 19, 20, 20, 45, 55, 56, 61, 71, 71, 71, 72, 79, 81),
  message: "the printed median exposure of a field changed",
)

#assert(
  fields.map(f => f.n) == (17, 15, 18, 10, 14, 38, 8, 12, 19, 8, 8, 12, 8, 22),
  message: "the number of majors in a field changed",
)
#let field(name) = fields.find(f => f.name == name)
#let straddles(f, key, cut) = f.majors.any(m => m.at(key) < cut) and f.majors.any(m => m.at(key) > cut)
#assert(
  fields.filter(f => straddles(f, "pct", 50)).len() == 11,
  message: "the number of fields with majors on both sides of the 50th percentile changed",
)
#assert(
  (
    fields.filter(f => correlation(f.majors) > 0).len(),
    fields.filter(f => correlation(f.majors) < 0).len(),
  ) == (9, 5),
  message: "the signs of the within-field correlations changed",
)
#assert(
  fields.filter(f => not (straddles(f, "pct", 50))).map(f => f.name)
    == ("Agriculture", "Visual & Performing Arts", "Foreign Languages"),
  message: "the fields without majors on both sides of the 50th percentile changed",
)
#assert(
  ("Visual & Performing Arts", "Architecture").map(f => calc.round(correlation(field(f).majors), digits: 2)) == (0.64, -0.63),
  message: "the printed within-field correlations changed",
)
#assert(
  ("Engineering Tech", "Engineering").all(f => field(f).majors.all(m => m.salary > all-median)),
  message: "an Engineering Tech or Engineering major no longer starts above the all-majors median",
)
#assert(
  field("Visual & Performing Arts").majors.all(m => m.salary < all-median),
  message: "a Visual & Performing Arts major no longer starts below the all-majors median",
)

#assert(
  fields.filter(f => not (straddles(f, "salary", all-median))).map(f => f.name)
    == ("Engineering Tech", "Visual & Performing Arts", "Engineering"),
  message: "the fields whose majors all sit on one side of the all-majors median changed",
)

// Salary spans of the strips, in dollars. Every strip shares them.
#let salary-limits = (0, 115000)
#let guides-at = (25000, 50000, 75000, 100000)
#assert(
  majors.all(m => m.salary > salary-limits.at(0) and m.salary < salary-limits.at(1)),
  message: "a salary now falls outside the strip limits",
)

#let ink = theme-minimal().at("ink", default: black)
#let dark = ink.oklab().components().first() > 50%

// A diverging ramp centred on the 50th percentile: orange for low exposure, blue
// for high, and a grey in the middle. On the light page the strong ends are the
// dark ones, and on the dark page they are the pale ones. Each arm passes
// validate_palette.js --ordinal against #fbfaf7 or #0d1626, and the grey clears
// 3:1 on the dark page and 2:1 on the light page.
#let ramp = if dark {
  (rgb("#f6bb86"), rgb("#dd9250"), rgb("#b5703f"), rgb("#5c6575"), rgb("#4f7fc0"), rgb("#7aa6e0"), rgb("#b0cdf5"))
} else {
  (rgb("#8f3305"), rgb("#d4580f"), rgb("#eda35f"), rgb("#aaa59b"), rgb("#8fb4e3"), rgb("#2f6bb8"), rgb("#0f2f5f"))
}
#let ramp-gradient = gradient.linear(..ramp, space: oklab)
#let page-colour = rgb(sys.inputs.at("typst-render-background", default: "#fbfaf7"))

// IBM Plex Sans for the words, IBM Plex Mono for every reading. Both are
// vendored in assets/fonts.
#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

#let muted = ink.transparentize(35%)
#let guide-colour = ink.transparentize(82%)

// The strips and the axis in the column label share one x scale and one width.
#let strip-width = 9.2cm
#let cell-inset = 3pt
#let x-scale = scale-continuous(
  limits: salary-limits,
  breaks: guides-at,
  expand: (0%, 0%),
)

// Points are offset vertically by salary rank, so neighbours in salary do not
// overlap. The order of the levels is interleaved so that neighbours never form a
// rising or falling run that would read as a slope.
#let level-order = (0, 3, 1, 4, 2, 5)
#let levels = level-order.len()

#let strip(name) = {
  let f = field(name)
  plot(
    data: f.majors.enumerate().map(((i, m)) => (..m, y: level-order.at(calc.rem(i, levels)) - (levels - 1) / 2)),
    mapping: aes(x: "salary", y: "y", fill: "pct"),
    layers: (
      geom-vline(
        data: guides-at.map(v => (v: v)),
        mapping: aes(xintercept: "v"),
        colour: guide-colour,
        stroke: 0.4pt,
      ),
      geom-vline(xintercept: all-median, colour: muted, stroke: 0.6pt, linetype: "dashed"),
      geom-point(size: 2.6pt, colour: page-colour, stroke: 0.4pt),
    ),
    scales: scales(
      x: x-scale,
      y: scale-continuous(limits: (-levels / 2 - 0.5, levels / 2 + 0.5), expand: (0%, 0%)),
      fill: scale-gradientn(colours: ramp, limits: (0, 100)),
    ),
    guides: guides(default: none),
    theme: theme-void(),
    width: strip-width,
    height: 0.62cm,
  )
}

#let axis = plot(
  data: guides-at.map(v => (salary: v, y: 0, label: text(font: mono, size: 5.5pt, fill: muted)[\$#(v / 1000)k])),
  mapping: aes(x: "salary", y: "y"),
  layers: (
    geom-typst(mapping: aes(label: "label"), anchor: "center"),
  ),
  scales: scales(x: x-scale, y: scale-continuous(limits: (-2, 2), expand: (0%, 0%))),
  guides: guides(default: none),
  theme: theme-void(),
  width: strip-width,
  height: 0.3cm,
)

#let bar-width = 2.6cm
#let bar(v) = box(width: bar-width + 0.7cm, height: 0.34cm)[
  #place(horizon + left, rect(width: bar-width * v / 100, height: 0.34cm, fill: ramp-gradient.sample(v * 1%), stroke: none))
  #place(horizon + left, dx: bar-width * v / 100 + 4pt, text(font: mono, size: 6.5pt, fill: ink)[#calc.floor(v + 0.5)])
]

#let legend = box(baseline: 1pt)[
  #text(font: mono, size: 6pt)[0]
  #box(width: 1.6cm, height: 0.7em, baseline: 0.1em, fill: ramp-gradient, stroke: none)
  #text(font: mono, size: 6pt)[100]
]

#let rows = fields.map(f => (field: f.name, n: f.n, med: f.med, strip: f.name))

#let figure-table(width) = {
  let n-width = 1.2cm
  let med-width = bar-width + 0.7cm + 2 * cell-inset
  let strip-column = strip-width + 2 * cell-inset
  keisen.display-table(
    rows,
    keisen.table-header(
      title: text(font: sans, size: 14pt, weight: "bold")[Fields Sit at Different AI Exposure, but Pay Ignores It],
      subtitle: text(font: sans, size: 7pt)[
        Each point is one of the #majors.len() majors, placed by median starting salary and coloured by AI exposure percentile (#legend).
        Bars show the median exposure of the majors in each of the #fields.len() broad fields with #min-majors or more majors.
        The dashed line is the median of all #majors.len() majors, #format-number(prefix: "\u{24}")(all-median).
      ],
    ),
    keisen.table-stub(rowname: "field", label: [Broad field]),
    keisen.columns-label(
      n: [Majors],
      med: [Median exposure percentile],
      strip: stack(
        spacing: 2pt,
        text(font: sans, size: 6.5pt, weight: "bold")[Median starting salary],
        axis,
      ),
    ),
    keisen.columns-align(start, columns: "med"),
    keisen.columns-align(center, columns: "n"),
    keisen.columns-width((field: width - n-width - med-width - strip-column, n: n-width, med: med-width, strip: strip-column)),
    keisen.format("med", bar),
    keisen.format("strip", strip),
    keisen.grand-summary-rows(functions: ("": col => axis), columns: "strip", format: v => v),
    keisen.table-source-note(text(font: sans, size: 5.5pt)[
      Salaries are pooled medians one year after graduation, and the exposure of a major is the mean over the occupations it leads to.
      Source: TidyTuesday 2026-10-20. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
    keisen.table-options(
      table-font: sans,
      table-font-size: 7pt,
      table-width: width,
      cell-inset: cell-inset,
      cell-vertical-align: horizon,
      column-labels-border-bottom: 0.5pt + muted,
      column-labels-size: 6.5pt,
      stub-weight: "medium",
    ),
    theme: keisen.theme-minimal(),
  )
}

// The table keeps its natural height and is only scaled down when the page is
// shorter, so the featured image shows the same figure as plot.svg with empty
// bands left and right.
#layout(size => {
  let table = figure-table(size.width)
  let height = measure(width: size.width, table).height
  if height > size.height {
    align(center + horizon, scale(size.height / height * 100%, reflow: true, table))
  } else {
    table
  }
})
