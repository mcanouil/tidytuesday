// Gribouille and Keisen come from the typst-render preamble
// (assets/typst/_preamble.typ), so this file does not import them.

// Grambank records, for each language, whether a grammatical feature is present
// (1) or absent (0). The data flags 11 of the 195 features as word-order
// features. For every pair of them, the figure gives the phi coefficient, the
// Pearson correlation of two yes or no answers, over the languages that have a
// known answer to both.
// Source: data/grambank_values.csv (TidyTuesday 2026-11-03).
#let features = (
  GB133: "Verb-final order",
  GB131: "Verb-initial order",
  GB075: "Postpositions",
  GB074: "Prepositions",
  GB328: "Relative clause before the noun",
  GB327: "Relative clause after the noun",
  GB422: "Complementiser after the verb",
  GB421: "Complementiser before the verb",
  GB022: "Articles before the noun",
  GB023: "Articles after the noun",
  GB262: "Question particle at the start",
)

#let answers = {
  let found = (:)
  for row in csv("data/grambank_values.csv", row-type: dictionary) {
    if row.parameter_id in features and row.value in ("0", "1") {
      let so-far = found.at(row.parameter_id, default: (:))
      so-far.insert(row.language_id, row.value == "1")
      found.insert(row.parameter_id, so-far)
    }
  }
  found
}

#let phi(a, b) = {
  let x = answers.at(a)
  let y = answers.at(b)
  let both = x.keys().filter(l => l in y)
  let count(p, q) = both.filter(l => x.at(l) == p and y.at(l) == q).len()
  let (n11, n10, n01, n00) = (count(true, true), count(true, false), count(false, true), count(false, false))
  (n11 * n00 - n10 * n01) / calc.sqrt((n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00))
}

// Features run from the one that goes most with verb-final order to the one that
// goes least with it.
#let order = features.keys().sorted(key: f => -phi("GB133", f))
#let round2(v) = calc.round(v, digits: 2)
#assert(
  (round2(phi("GB133", "GB074")), round2(phi("GB133", "GB075")), round2(phi("GB133", "GB328"))) == (-0.7, 0.6, 0.49),
  message: "the printed correlations with verb-final order changed",
)
#assert(
  order.slice(0, 3) == ("GB133", "GB075", "GB328"),
  message: "the features that go most with verb-final order changed",
)
#assert(
  order.last() == "GB074" and round2(phi("GB327", "GB328")) == -0.55,
  message: "the feature that goes least with verb-final order, or the printed relative clause correlation, changed",
)

#let ink = theme-minimal().at("ink", default: black)
#let dark = ink.oklab().components().first() > 50%
#let page-colour = theme-minimal().at("paper", default: white)
#let muted = ink.transparentize(35%)

// Blue for features that go together, orange for features that exclude each
// other, and the page colour at zero. The strong ends are the dark ones on the
// light page and the pale ones on the dark page, as in the other figures.
#let positive = if dark { rgb("#5a8fd8") } else { rgb("#2f6bb8") }
#let negative = if dark { rgb("#d07a2c") } else { rgb("#c2510e") }
#let full-strength = 0.7
#let cell-colour(v) = {
  let strength = calc.min(calc.abs(v) / full-strength, 1) * 100%
  color.mix((if v > 0 { positive } else { negative }, strength), (page-colour, 100% - strength), space: oklab)
}
// Text on a strong cell takes the page colour on the light page, where strong cells
// are dark, and on the dark page only for the palest cells.
#let text-colour(v) = if calc.abs(v) >= (if dark { 0.6 } else { 0.45 }) { page-colour } else { ink }

#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

#let cell = 0.6cm
#let label-room = 7.4

// One tile for each pair of features up to the diagonal, with the name of a
// feature placed just after its diagonal tile, so the upper right of the
// figure stays free for the labels. Row i is drawn at y = -i, from the top.
#let tiles = {
  let found = ()
  for (i, a) in order.enumerate() {
    for (j, b) in order.slice(0, i + 1).enumerate() {
      let v = if i == j { none } else { phi(a, b) }
      found.push((
        x: j,
        y: -i,
        fill: if v == none { ink.transparentize(88%) } else { cell-colour(v) },
        label: if v != none and calc.abs(v) >= 0.3 {
          text(font: mono, size: 5pt, fill: text-colour(v))[#calc.round(v, digits: 2)]
        } else { none },
      ))
    }
  }
  found
}
#let names-at = order.enumerate().map(((i, a)) => (
  x: i + 0.65,
  y: -i,
  label: text(font: sans, size: 7pt, fill: ink)[#features.at(a)],
))

#let heatmap = plot(
  data: tiles,
  mapping: aes(x: "x", y: "y"),
  layers: (
    geom-tile(mapping: aes(fill: "fill"), width: 0.92, height: 0.92),
    geom-typst(data: tiles.filter(t => t.label != none), mapping: aes(label: "label"), anchor: "center"),
    geom-typst(data: names-at, mapping: aes(label: "label"), anchor: "west"),
  ),
  scales: scales(
    x: scale-continuous(limits: (-0.5, order.len() - 0.5 + label-room), expand: (0%, 0%)),
    y: scale-continuous(limits: (-order.len() + 0.5, 0.5), expand: (0%, 0%)),
    fill: scale-identity(),
  ),
  guides: guides(default: none),
  theme: theme-void(),
  width: cell * (order.len() + label-room),
  height: cell * order.len(),
)

#let key-steps = (-0.7, -0.35, 0, 0.35, 0.7)
#let scale-key = grid(
  columns: key-steps.map(_ => 0.9cm),
  rows: (0.3cm, auto),
  row-gutter: 2pt,
  ..key-steps.map(v => box(width: 100%, height: 0.3cm, fill: cell-colour(v), stroke: 0.4pt + ink.transparentize(80%))),
  ..key-steps.map(v => align(center, text(font: mono, size: 5.5pt, fill: muted)[#v])),
)

#set text(font: sans)
#layout(size => {
  let body = block(width: size.width, align(left, {
    v(5pt)
    text(size: 13pt, weight: "bold", fill: ink)[Verb-Final Languages Put Adpositions and Relative Clauses Before the Noun]
    v(3pt)
    text(size: 7pt, fill: ink)[
      Each cell is the correlation, over the languages that have an answer to both, between two of the #features.len() word-order features that Grambank flags.
      Orange cells are features that rarely go together, and blue cells are features that tend to.
      Cells between -0.3 and 0.3 carry no number.
    ]
    v(4pt)
    grid(
      columns: (1fr, auto),
      column-gutter: 10pt,
      heatmap,
      align(top + left, block(width: 5cm, {
        text(size: 6.5pt, fill: ink)[Correlation]
        v(2pt)
        scale-key
        v(10pt)
        text(size: 7pt, fill: ink)[
          Verb-final order goes with postpositions (#calc.round(phi("GB133", "GB075"), digits: 2)) and with a relative clause before the noun (#calc.round(phi("GB133", "GB328"), digits: 2)).
          It goes against prepositions (#calc.round(phi("GB133", "GB074"), digits: 2)), which is its strongest link.
        ]
      })),
    )
    v(2pt)
    text(size: 5.5pt, fill: muted)[
      Source: TidyTuesday 2026-11-03, Grambank. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]
  }))
  let height = measure(width: size.width, body).height
  if height > size.height {
    align(center + horizon, scale(size.height / height * 95%, reflow: true, body))
  } else {
    align(horizon, body)
  }
})
