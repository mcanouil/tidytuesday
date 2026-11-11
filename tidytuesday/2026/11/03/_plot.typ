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
  order
    == ("GB133", "GB075", "GB328", "GB422", "GB023", "GB262", "GB022", "GB131", "GB421", "GB327", "GB074"),
  message: "the order of the features changed",
)
#assert(
  calc.min(..order.map(a => calc.min(..order.map(b => answers.at(a).keys().filter(l => l in answers.at(b)).len())))) == 950,
  message: "the smallest number of languages behind a cell changed",
)
#assert(
  round2(phi("GB327", "GB328")) == -0.55,
  message: "the printed relative clause correlation changed",
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
#let half(c) = color.mix((c, 50%), (page-colour, 50%), space: oklab)
#let ramp = (negative, half(negative), page-colour, half(positive), positive)

// A number takes the ink or the page colour, whichever is further in lightness
// from its cell, so it stays readable in both themes.
#let lightness(c) = c.oklab().components().first()
#let text-colour(v) = {
  let cell = gradient.linear(..ramp, space: oklab).sample((v + 1) / 2 * 100%)
  let l = lightness(cell)
  if calc.abs(l - lightness(ink)) >= calc.abs(l - lightness(page-colour)) { ink } else { page-colour }
}

#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

#let label-room = 7.4

// One tile for each pair of features up to the diagonal, with the name of a
// feature placed just after its diagonal tile, so the upper right of the
// figure stays free for the labels. Row i is drawn at y = -i, from the top.
#let pairs = {
  let found = ()
  for (i, a) in order.enumerate() {
    for (j, b) in order.slice(0, i).enumerate() {
      let v = phi(a, b)
      found.push((
        x: j,
        y: -i,
        r: v,
        label: if calc.abs(v) >= 0.3 { text(font: mono, size: 5pt, fill: text-colour(v))[#calc.round(v, digits: 2)] },
      ))
    }
  }
  found
}
#let diagonal = order.enumerate().map(((i, a)) => (
  x: i,
  y: -i,
  name: text(font: sans, size: 7pt, fill: ink)[#features.at(a)],
))

#let figure-plot(width, height) = plot(
  data: pairs,
  mapping: aes(x: "x", y: "y"),
  layers: (
    geom-tile(data: diagonal, fill: ink.transparentize(88%), width: 0.92, height: 0.92),
    geom-tile(mapping: aes(fill: "r"), width: 0.92, height: 0.92),
    geom-typst(data: pairs.filter(t => t.label != none), mapping: aes(label: "label"), anchor: "center"),
    geom-typst(data: diagonal, mapping: aes(x: "x", y: "y", label: "name"), anchor: "west", nudge-x: 0.65),
  ),
  scales: scales(
    x: scale-continuous(limits: (-0.5, order.len() - 0.5 + label-room), expand: (0%, 0%)),
    y: scale-continuous(limits: (-order.len() + 0.5, 0.5), expand: (0%, 0%)),
    fill: scale-gradientn(colours: ramp, limits: (-1, 1), breaks: (-1, -0.5, 0, 0.5, 1), name: "Correlation"),
  ),
  labels: labels(
    title: "Verb-Final Languages Put Adpositions After the Noun and Relative Clauses Before It",
    subtitle: [
      Each cell is the correlation between two of the #features.len() word-order features that Grambank flags, and cells between -0.3 and 0.3 carry no number.\
      Verb-final order goes with postpositions (#calc.round(phi("GB133", "GB075"), digits: 2)) and a relative clause before the noun (#calc.round(phi("GB133", "GB328"), digits: 2)), and against prepositions (#calc.round(phi("GB133", "GB074"), digits: 2)).
    ],
    caption: [Source: TidyTuesday 2026-11-03, Grambank. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].],
    x: none,
    y: none,
  ),
  theme: theme-void(
    plot-title: element-text(font: sans, size: 12pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: sans, size: 7pt, colour: ink),
    plot-caption: element-text(font: sans, size: 5.5pt, colour: muted),
    legend-text: element-text(font: mono, size: 5.5pt, colour: muted),
    legend-title: element-text(font: sans, size: 6.5pt, colour: ink),
    // theme-void has no inset, and the page has no margin, so this keeps the
    // title and caption off the edge.
    plot-background: element-rect(),
  ),
  width: width,
  height: height,
)

#fit-page(figure-plot, natural-height: 10.4cm)
