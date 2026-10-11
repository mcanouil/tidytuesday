// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per bottle of avocado oil sold in the US and tested for a 2020 study, with the lab's verdict on
// its purity and its fatty acid profile, as a percent of total fatty acids.
// Source: data/avocado_oil_bottles.csv (TidyTuesday 2026-10-06).
#let records = csv("data/avocado_oil_bottles.csv", row-type: dictionary)

#let bottles = records.map(r => (
  code: r.sample_code,
  grade: r.grade_labeled,
  price: float(r.cost_per_fl_oz),
  purity: r.purity_result,
  linoleic: float(r.c18_2_linoleic_pct),
  palmitoleic: float(r.c16_1_palmitoleic_pct),
))

#let pure = bottles.filter(b => b.purity == "pure")
#let suspected = bottles.filter(b => b.purity == "suspected")
#let soybean = bottles.filter(b => b.purity == "adulterated")

// The claim the title makes: each kind of fake fails on one of the two acids.
// Soybean oil is more than half linoleic acid, and the sunflower or safflower
// blends have less palmitoleic acid than any pure bottle.
#let soybean-line = 50
#assert(soybean.all(b => b.linoleic > soybean-line), message: "a soybean bottle is now below 50% linoleic acid")
#assert(
  (pure + suspected).all(b => b.linoleic < soybean-line),
  message: "a bottle that is not soybean oil is now above 50% linoleic acid",
)
#let palmitoleic-floor = calc.min(..pure.map(b => b.palmitoleic))
#assert(
  suspected.all(b => b.palmitoleic < palmitoleic-floor),
  message: "a suspected bottle now has as much palmitoleic acid as a pure one",
)

// A lab notebook: a graph-paper grid drawn in the ink of the theme that
// typst-render resolved, so the figure follows the light and dark toggle of the
// site. The marks are the emoji themselves, so the fruit, the bean and the
// flower carry their own colours. The text accents are mixed a quarter towards
// the ink so they keep their contrast on both grounds.
#let ink = theme-minimal().at("ink", default: black)
#let flesh = rgb("#a9c25a")
#let bean = color.mix((rgb("#b5603a"), 75%), (ink, 25%))
#let flower = color.mix((rgb("#c99400"), 75%), (ink, 25%))

// IBM Plex Sans for the title, IBM Plex Mono for every reading, as on a lab
// printout. Both, and the emoji font, are vendored in assets/fonts.
#let title-font = "IBM Plex Sans"
#let mono-font = "IBM Plex Mono"
#let emoji-font = "Noto Color Emoji"

#let emoji = (pure: "🥑", suspected: "🌻", adulterated: "🫘")
#let glyph(purity) = text(font: emoji-font, emoji.at(purity))

// The range the dataset's dictionary gives for authentic avocado oil, filled
// with a stipple of avocado flesh.
#let stipple = tiling(size: (3pt, 3pt))[
  #place(dx: 1pt, dy: 1pt, circle(radius: 0.5pt, fill: flesh))
]
#let typical = (xmin: 9, xmax: 20, ymin: 5, ymax: 9)

// The three soybean bottles share one point to within a percentage point, so
// they are stacked in a column there, in order of price, with the lab values
// in their labels.
#let stack-step = 0.75
#let marks = (
  pure.map(b => (..b, x: b.linoleic, y: b.palmitoleic))
    + suspected.map(b => (..b, x: b.linoleic, y: b.palmitoleic))
    + soybean
      .sorted(key: b => b.price)
      .enumerate()
      .map(((i, b)) => (..b, x: calc.min(..soybean.map(s => s.linoleic)), y: 0.2 + i * stack-step))
).map(b => (..b, content: glyph(b.purity)))

#let money(v) = "$" + format-number(digits: 2)(v)
#let grade(b) = if b.grade == "unspecified" { "no grade" } else { b.grade }
#let reading(b) = text(font: mono-font, size: 5.5pt, fill: ink)[
  *#b.code* #grade(b), #money(b.price)/fl oz
]

#let soybean-labels = {
  marks
    .filter(b => b.purity == "adulterated")
    .map(b => (x: b.x + 1.4, y: b.y, content: reading(b)))
}

// R1 sits just below and left of U4, so its label goes on its left.
#let left-labels = ("R1",)
#let suspected-labels = suspected.map(b => (
  x: b.linoleic + if b.code in left-labels { -1.2 } else { 1.2 },
  y: b.palmitoleic,
  content: reading(b),
  side: if b.code in left-labels { "east" } else { "west" },
))

#let notes = (
  (
    x: soybean-line + 0.6,
    y: 9.6,
    content: text(font: mono-font, size: 6pt, fill: bean)[
      #glyph("adulterated") *soybean oil* \ above #soybean-line% linoleic
    ],
  ),
  (
    x: 22,
    y: 3.8,
    content: text(font: mono-font, size: 6pt, fill: flower)[
      #glyph("suspected") *sunflower or safflower* \ linoleic looks normal, \ palmitoleic is too low
    ],
  ),
  (
    x: typical.xmax + 0.6,
    y: typical.ymax - 0.1,
    content: text(font: mono-font, size: 6pt, fill: ink)[
      #glyph("pure") *typical avocado oil* \ #pure.len() bottles judged pure
    ],
  ),
)

#plot(
  data: marks,
  mapping: aes(x: "x", y: "y"),
  layers: (
    geom-rect(
      data: (typical,),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      inherit-aes: false,
      fill: stipple,
      colour: flesh,
      stroke: 0.6pt,
    ),
    geom-vline(xintercept: soybean-line, colour: bean, stroke: 0.6pt, linetype: "dashed"),
    geom-typst(mapping: aes(label: "content"), size: 10pt),
    geom-typst(data: soybean-labels, mapping: aes(label: "content"), anchor: "west"),
    ..("west", "east").map(side => geom-typst(
      data: suspected-labels.filter(l => l.side == side),
      mapping: aes(label: "content"),
      anchor: side,
    )),
    geom-typst(data: notes, mapping: aes(label: "content"), anchor: "north-west"),
  ),
  scales: scales(
    x: scale-continuous(
      limits: (0, 70),
      breaks: range(0, 71, step: 10),
      minor-breaks: range(0, 71, step: 2),
      labels: format-number(suffix: "%"),
      expand: (0%, 0%),
    ),
    y: scale-continuous(
      limits: (-0.4, 10),
      breaks: range(0, 11, step: 2),
      minor-breaks: range(0, 11, step: 1),
      labels: format-number(suffix: "%"),
      expand: (0%, 0%),
    ),
  ),
  guides: guides(default: none),
  labels: labels(
    title: [Two Fatty Acids Give Away Every Fake Avocado Oil],
    subtitle: [
      #bottles.len() bottles of avocado oil sold in the US, tested at UC Davis and placed by two of the fatty acids the lab measured. \
      #text(fill: bean, weight: "semibold")[Linoleic acid] catches the #soybean.len() bottles of soybean oil. #text(fill: flower, weight: "semibold")[Palmitoleic acid] catches the #suspected.len() blends it misses.
    ],
    caption: [
      Each mark is one bottle. The three soybean bottles sit at the same point and are stacked by price. The stippled box is the range the dataset gives for authentic avocado oil. \
      Purity was judged by UC Davis from the full fatty acid, sterol and vitamin E profile; only two of those readings are drawn here. \
      Source: Green & Wang (2020), _Food Control_ 116, 107328 (TidyTuesday 2026-10-06). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: "Linoleic acid (C18:2), % of fatty acids",
    y: "Palmitoleic acid (C16:1)",
  ),
  theme: theme-minimal(
    plot-title: element-text(font: title-font, size: 16pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: title-font, size: 7.5pt, colour: ink),
    plot-caption: element-text(font: title-font, size: 5.5pt, colour: ink.transparentize(30%)),
    axis-text: element-text(font: mono-font, size: 6pt, colour: ink.transparentize(25%)),
    axis-title: element-text(font: mono-font, size: 6.5pt, colour: ink),
    panel-grid-major: element-line(colour: ink.transparentize(82%), stroke: 0.5pt),
    panel-grid-minor: element-line(colour: ink.transparentize(92%), stroke: 0.3pt),
  ),
  width: auto,
  height: auto,
)
