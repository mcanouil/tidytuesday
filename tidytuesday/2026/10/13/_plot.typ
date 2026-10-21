// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per frog or toad species described by AmphibiaWeb. `isocc` holds the
// ISO codes of the countries a species is native to, separated by commas.
// Source: data/frogs_and_toads_amphibiaweb.csv (TidyTuesday 2026-10-13).
#let frogs = csv("data/frogs_and_toads_amphibiaweb.csv", row-type: dictionary)

#let codes(r) = r.isocc.split(",").map(c => c.trim()).filter(c => c != "" and c != "NA")

// A species counts for every country in its list, and is "found in no other
// country" when the list holds exactly one code.
#let min-species = 20
#let countries = {
  let tally = (:)
  for r in frogs {
    let cs = codes(r)
    for c in cs {
      let t = tally.at(c, default: (n: 0, only: 0))
      tally.insert(c, (n: t.n + 1, only: t.only + if cs.len() == 1 { 1 } else { 0 }))
    }
  }
  tally
    .pairs()
    .map(((code, t)) => (code: code, n: t.n, only: t.only, share: t.only / t.n, x: calc.log(t.n, base: 10)))
    .filter(c => c.n >= min-species)
}

// The two countries the zoom panels open up.
#let country(code) = countries.find(c => c.code == code)
#let mg = country("MG")
#let bo = country("BO")

#let tally-by(rows, key) = {
  let t = (:)
  for r in rows {
    for k in key(r) { t.insert(k, t.at(k, default: 0) + 1) }
  }
  t.pairs().sorted(key: p => (-p.at(1), p.at(0)))
}
#let mg-families = tally-by(frogs.filter(r => codes(r) == ("MG",)), r => (r.family,))
#let bo-shared = tally-by(frogs.filter(r => "BO" in codes(r)), r => codes(r).filter(c => c != "BO")).slice(0, 5)

// Families whose species all live in one country.
#let one-country-families = {
  let by-family = (:)
  for r in frogs {
    let seen = by-family.at(r.family, default: ())
    by-family.insert(r.family, (seen + codes(r)).dedup())
  }
  by-family.pairs().filter(((_, cs)) => cs.len() == 1)
}

#assert(frogs.len() == 8018, message: "the species count changed")
#assert(frogs.filter(r => codes(r).len() == 1).len() == 5985, message: "the one-country count changed")
#assert(frogs.filter(r => codes(r).len() == 0).len() == 31, message: "species without a country changed")
#assert(countries.len() == 91, message: "countries with 20 or more species changed")
#assert((mg.n, mg.only) == (443, 440), message: "Madagascar changed")
#assert((bo.n, bo.only) == (262, 76), message: "Bolivia changed")
#assert(
  mg-families == (("Mantellidae", 296), ("Microhylidae", 133), ("Hyperoliidae", 11)),
  message: "Madagascar families changed",
)
#assert(
  bo-shared == (("BR", 133), ("PE", 116), ("CO", 67), ("EC", 59), ("AR", 55)),
  message: "Bolivia shared counts changed",
)
#assert(one-country-families.len() == 8, message: "families in one country changed")

#let remote = ("MG", "AU", "PH", "LK", "CU", "JP", "JM", "PG", "ID")
#let near = ("TT", "SG", "TW", "PR", "HT", "DO")
#let group(code) = if code in remote { "remote" } else if code in near { "near" } else { "mainland" }

#let remote-points = countries.filter(c => group(c.code) == "remote")
#let near-points = countries.filter(c => group(c.code) == "near")
#let mainland-points = countries.filter(c => group(c.code) == "mainland")
#assert((remote-points.len(), near-points.len()) == (9, 6), message: "an island group lost a country below 20 species")
#assert(
  remote-points.filter(c => c.share > 0.8).len() == 6,
  message: "the number of remote islands that keep more than 80% changed",
)
#assert(mainland-points.all(c => c.share < 0.75), message: "a mainland country now keeps 75% or more")
#assert(
  (mainland-points.len(), mainland-points.filter(c => c.share < 0.25).len()) == (76, 56),
  message: "the number of mainland countries that keep under a quarter changed",
)
#assert(
  (country("BR").n, country("BR").only) == (1173, 837),
  message: "Brazil changed",
)
#assert(
  near-points.all(c => c.share > 0.03 and c.share < 0.55),
  message: "the range of the islands near a mainland changed",
)
#assert(calc.round(frogs.filter(r => codes(r).len() == 1).len() / frogs.len() * 100) == 75, message: "the 75% changed")
#let family-size(f) = frogs.filter(r => r.family == f).len()
#assert(
  one-country-families.filter(((f, _)) => f in ("Brachycephalidae", "Micrixalidae", "Ranixalidae")).map(((f, cs)) => (f, cs.first(), family-size(f)))
    == (("Brachycephalidae", "BR", 84), ("Ranixalidae", "IN", 19), ("Micrixalidae", "IN", 24)),
  message: "the one-country families changed",
)
#assert((family-size("Mantellidae"), mg-families.first().last()) == (300, 296), message: "Mantellidae changed")

// Every country the alt text or prose prints: species count and whole-number
// share of them found in no other country.
#let printed = (
  MG: (443, 99), CU: (71, 94), AU: (259, 92), LK: (109, 85), JM: (25, 84), PH: (114, 83), PG: (435, 78),
  JP: (49, 65), ID: (400, 59), PR: (26, 54), HT: (57, 49), DO: (50, 38), TW: (39, 36), TT: (40, 18),
  SG: (28, 4), BO: (262, 29), BR: (1173, 71),
)
#for (code, (n, pct)) in printed {
  let c = country(code)
  assert((c.n, calc.round(c.share * 100)) == (n, pct), message: "the printed numbers for " + code + " changed")
}
#assert(country("SG").only == 1, message: "Singapore no longer keeps one species")
#assert(
  calc.round(calc.max(..mainland-points.map(c => c.share)) * 100) == 73,
  message: "the highest mainland share is no longer 73%",
)

#let ink = theme-minimal().at("ink", default: black)
#let island-colour = rgb("#d4580f")
#let near-colour = rgb("#2f74c0")
#let mainland-colour = rgb("#8b929c")
#let highlight = rgb("#1a9a6a")
#let group-colour = (remote: island-colour, near: near-colour, mainland: mainland-colour)

// Alegreya for the words, Alegreya Sans for every label and reading. Both are
// vendored in assets/fonts.
#let serif = "Alegreya"
#let sans = "Alegreya Sans"

#let names = (
  MG: "Madagascar", AU: "Australia", PH: "Philippines", LK: "Sri Lanka", CU: "Cuba", JP: "Japan", JM: "Jamaica",
  PG: "Papua New Guinea", ID: "Indonesia", TT: "Trinidad and Tobago", SG: "Singapore", TW: "Taiwan",
  PR: "Puerto Rico", HT: "Haiti", DO: "Dominican Republic", BR: "Brazil", BO: "Bolivia", PE: "Peru",
  CO: "Colombia", EC: "Ecuador", AR: "Argentina",
)

// Hand-placed labels: the edge of the text that sits on the point, and the
// offset from it in log10 species (x) and share (y).
#let label-offsets = (
  MG: ("east", -0.09, 0),
  AU: ("east", -0.04, 0),
  PG: ("west", 0.04, 0),
  ID: ("west", 0.04, 0),
  BR: ("east", -0.04, 0),
  BO: ("south", 0, 0.065),
  LK: ("east", -0.03, 0.025),
  PH: ("west", 0.03, -0.025),
  CU: ("east", -0.04, 0),
  JP: ("west", 0.04, 0),
  JM: ("west", 0.04, 0),
  PR: ("west", 0.04, 0),
  HT: ("west", 0.04, 0),
  DO: ("west", 0.04, 0.03),
  TW: ("east", -0.04, 0),
)
#let label-points = countries.filter(c => c.code in label-offsets)

// Two labels sit in a clear patch of the plot, joined to their point by a
// connector. The offsets are in log10 species (x) and share (y).
#let moved-labels = (TT: (-0.12, 0.105), SG: (-0.197, 0.194))
#let moved-points = countries.filter(c => c.code in moved-labels)

// Scatter on log10(species). The two zoom panels sit to its right, in the same
// data space, so the leader lines end exactly on them.
#let scatter-x = (1.2, 3.12)
#let panel-x = 3.36
#let bar-label-x = panel-x + 0.4
#let bar-start = panel-x + 0.44
#let bar-full = 0.78
#let bar-scale = 300
#let x-limit = 4.7
#let bar-length(v) = bar-full * v / bar-scale
#let panel-text(body, size: 6.5pt, weight: "regular") = text(font: sans, size: size, weight: weight, fill: ink, body)

#let breaks = (20, 50, 100, 200, 500, 1000)
#let grid-colour = ink.transparentize(85%)
#let grid = (
  breaks.map(b => (x: calc.log(b, base: 10), xend: calc.log(b, base: 10), y: 0, yend: 1))
    + range(0, 5).map(i => (x: scatter-x.at(0), xend: scatter-x.at(1), y: i / 4, yend: i / 4))
)

#let panels = (
  (
    code: "MG",
    top: 1.05,
    bottom: 0.63,
    title: [#names.MG keeps #mg.only of its #mg.n species],
    sub: [Its #mg.only one-country species, by family],
    bars: mg-families.map(((f, v)) => (label: text(style: "italic", f), v: v)),
    first-bar: 0.83,
    link-y: 0.93,
  ),
  (
    code: "BO",
    top: 0.51,
    bottom: -0.04,
    title: [#names.BO keeps only #bo.only of its #bo.n species],
    sub: [Species it shares with the five countries below],
    bars: bo-shared.map(((c, v)) => (label: names.at(c), v: v)),
    first-bar: 0.285,
    link-y: 0.30,
  ),
)
#let bar-gap = 0.07
#let panel-bars = panels.map(p => p.bars.enumerate().map(((i, b)) => (..b, y: p.first-bar - i * bar-gap))).flatten()
#let panel-rects = panels.map(p => (xmin: panel-x, xmax: x-limit, ymin: p.bottom, ymax: p.top))
#let links = panels.map(p => {
  let c = country(p.code)
  (x: c.x + 0.045, y: c.share, xend: panel-x, yend: p.link-y)
})

#plot(
  data: countries,
  mapping: aes(x: "x", y: "share"),
  layers: (
    geom-segment(
      data: grid,
      mapping: aes(x: "x", y: "y", xend: "xend", yend: "yend"),
      inherit-aes: false,
      colour: grid-colour,
      stroke: 0.4pt,
    ),
    geom-rect(
      data: panel-rects,
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      inherit-aes: false,
      fill: ink.transparentize(95%),
    ),
    geom-segment(
      data: links,
      mapping: aes(x: "x", y: "y", xend: "xend", yend: "yend"),
      inherit-aes: false,
      colour: highlight,
      stroke: 0.7pt,
    ),
    geom-rect(
      data: panel-bars.map(b => (xmin: bar-start, xmax: bar-start + bar-length(b.v), ymin: b.y - 0.025, ymax: b.y + 0.025)),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      inherit-aes: false,
      fill: highlight,
    ),
    geom-typst(
      data: panel-bars.map(b => (x: bar-label-x, y: b.y, label: panel-text(b.label))),
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: "east",
    ),
    geom-typst(
      data: panel-bars.map(b => (x: bar-start + bar-length(b.v) + 0.02, y: b.y, label: panel-text(weight: "bold")[#b.v])),
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: "west",
    ),
    geom-typst(
      data: panels.map(p => (
        x: panel-x + 0.04,
        y: p.top - 0.015,
        label: [#panel-text(size: 7.5pt, weight: "bold")[#p.title] \ #panel-text(size: 6pt)[#p.sub]],
      )),
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: "north-west",
    ),
    geom-point(
      data: d => d.filter(c => group(c.code) == "mainland"),
      size: 2.2pt,
      colour: mainland-colour,
      fill: mainland-colour,
    ),
    geom-point(
      data: d => d.filter(c => group(c.code) == "near"),
      shape: "diamond",
      size: 3.8pt,
      colour: near-colour,
      fill: near-colour,
    ),
    geom-point(
      data: d => d.filter(c => group(c.code) == "remote"),
      size: 3.6pt,
      colour: island-colour,
      fill: island-colour,
    ),
    geom-point(
      data: d => d.filter(c => c.code in ("MG", "BO")),
      size: 7.5pt,
      fill: none,
      colour: highlight,
      stroke: 1pt,
    ),
    geom-typst(
      data: moved-points.map(c => (
        x: c.x,
        y: c.share,
        label: panel-text(names.at(c.code)),
        nudge-x: moved-labels.at(c.code).first(),
        nudge-y: moved-labels.at(c.code).last(),
      )),
      mapping: aes(x: "x", y: "y", label: "label", nudge-x: "nudge-x", nudge-y: "nudge-y"),
      inherit-aes: false,
      anchor: "west",
      segment: true,
      segment-colour: ink.transparentize(40%),
    ),
    ..label-offsets.values().map(o => o.first()).dedup().map(side => geom-typst(
      data: label-points
        .filter(c => label-offsets.at(c.code).first() == side)
        .map(c => (
          x: c.x + label-offsets.at(c.code).at(1),
          y: c.share + label-offsets.at(c.code).at(2),
          label: panel-text(names.at(c.code)),
        )),
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: side,
    )),
    geom-typst(
      data: ((x: scatter-x.at(1), y: 0.02, label: panel-text(size: 6pt)[Native species in the country, log scale]),),
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: "south-east",
    ),
  ),
  scales: scales(
    x: scale-continuous(
      limits: (scatter-x.at(0), x-limit),
      breaks: breaks.map(b => calc.log(b, base: 10)),
      labels: breaks.map(str),
      expand: (0%, 0%),
    ),
    y: scale-continuous(
      limits: (-0.04, 1.06),
      breaks: range(0, 5).map(i => i / 4),
      labels: format-percent(),
      expand: (0%, 0%),
    ),
  ),
  guides: guides(default: none),
  labels: labels(
    title: [Remote Islands Keep Their Frogs to Themselves],
    subtitle: [
      Share of each country's native frog and toad species found in no other country, for the #countries.len() countries with #min-species or more species. \
      #text(fill: island-colour, weight: "semibold")[Remote islands] (circles) and #text(fill: near-colour, weight: "semibold")[islands near a mainland] (diamonds) against #text(fill: mainland-colour, weight: "semibold")[mainland countries].
    ],
    caption: [
      Species count in each country, from the ISO codes AmphibiaWeb lists as native. Both panels use one bar scale. \
      Source: AmphibiaWeb (TidyTuesday 2026-10-13). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: "Found in no other country",
  ),
  theme: theme-minimal(
    plot-title: element-text(font: serif, size: 16pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: serif, size: 7.5pt, colour: ink),
    plot-caption: element-text(font: serif, size: 5.5pt, colour: ink.transparentize(30%)),
    axis-text: element-text(font: sans, size: 6pt, colour: ink.transparentize(25%)),
    axis-title: element-text(font: sans, size: 6.5pt, colour: ink),
    panel-grid: element-blank(),
  ),
  width: auto,
  height: auto,
)
