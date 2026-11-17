// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per frog or toad species described by AmphibiaWeb. `isocc` holds the
// ISO codes of the countries a species is native to, separated by commas.
// Source: data/frogs_and_toads_amphibiaweb.csv (TidyTuesday 2026-10-13).
#let frogs = csv("data/frogs_and_toads_amphibiaweb.csv", row-type: dictionary).map(r => (
  family: r.family,
  codes: r.isocc.split(",").map(c => c.trim()).filter(c => c != "" and c != "NA"),
))

// A species counts for every country in its list, and is "found in no other
// country" when the list holds exactly one code.
#let min-species = 20
#let countries = {
  let tally = (:)
  for r in frogs {
    let cs = r.codes
    for c in cs {
      let t = tally.at(c, default: (n: 0, only: 0))
      tally.insert(c, (n: t.n + 1, only: t.only + if cs.len() == 1 { 1 } else { 0 }))
    }
  }
  tally
    .pairs()
    .map(((code, t)) => (code: code, n: t.n, only: t.only, share: t.only / t.n))
    .filter(c => c.n >= min-species)
}

// The two countries the zoom panels open up.
#let country(code) = {
  let c = countries.find(c => c.code == code)
  assert(c != none, message: code + " no longer has " + str(min-species) + " or more species")
  c
}
#let mg = country("MG")
#let bo = country("BO")

#let tally-by(rows, key) = {
  let t = (:)
  for r in rows {
    for k in key(r) { t.insert(k, t.at(k, default: 0) + 1) }
  }
  t.pairs().sorted(key: p => (-p.at(1), p.at(0)))
}
#let mg-families = tally-by(frogs.filter(r => r.codes == ("MG",)), r => (r.family,))
#let bo-shared = tally-by(frogs.filter(r => "BO" in r.codes), r => r.codes.filter(c => c != "BO")).slice(0, 5)

// Families whose species all live in one country.
#let one-country-families = {
  let codes-by-family = (:)
  for r in frogs {
    let seen = codes-by-family.at(r.family, default: (:))
    for c in r.codes { seen.insert(c, true) }
    codes-by-family.insert(r.family, seen)
  }
  codes-by-family.pairs().filter(((_, seen)) => seen.len() == 1).map(((f, seen)) => (f, seen.keys().first()))
}
#let family-sizes = tally-by(frogs, r => (r.family,)).to-dict()
#let one-country-species = frogs.filter(r => r.codes.len() == 1).len()

#assert(frogs.len() == 8018, message: "the species count changed")
#assert(one-country-species == 5985, message: "the one-country count changed")
#assert(frogs.filter(r => r.codes.len() == 0).len() == 31, message: "species without a country changed")
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

#let remote-points = countries.filter(c => c.code in remote)
#let near-points = countries.filter(c => c.code in near)
#let mainland-points = countries.filter(c => c.code not in remote + near)
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
  near-points.all(c => c.share > 0.03 and c.share < 0.55),
  message: "the range of the islands near a mainland changed",
)
#assert(calc.round(one-country-species / frogs.len() * 100) == 75, message: "the 75% changed")
#assert(
  one-country-families.filter(((f, _)) => f in ("Brachycephalidae", "Micrixalidae", "Ranixalidae")).map(((f, code)) => (f, code, family-sizes.at(f)))
    == (("Brachycephalidae", "BR", 84), ("Ranixalidae", "IN", 19), ("Micrixalidae", "IN", 24)),
  message: "the one-country families changed",
)
#assert((family-sizes.at("Mantellidae"), mg-families.first().last()) == (300, 296), message: "Mantellidae changed")

// Every country the alt text or prose prints: species count and whole-number
// share of them found in no other country. Brazil and Singapore also print
// their one-country species count, as a third value.
#let printed = (
  MG: (443, 99), CU: (71, 94), AU: (259, 92), LK: (109, 85), JM: (25, 84), PH: (114, 83), PG: (435, 78),
  JP: (49, 65), ID: (400, 59), PR: (26, 54), HT: (57, 49), DO: (50, 38), TW: (39, 36), TT: (40, 18),
  SG: (28, 4, 1), BO: (262, 29), BR: (1173, 71, 837),
)
#for (code, (n, pct, ..only)) in printed {
  let c = country(code)
  assert((c.n, calc.round(c.share * 100)) == (n, pct), message: "the printed numbers for " + code + " changed")
  if only.len() > 0 {
    assert(c.only == only.first(), message: "the printed one-country count for " + code + " changed")
  }
}
#assert(bo.n - bo.only == 186, message: "the number of species Bolivia shares changed")
#assert(
  calc.max(..mainland-points.map(c => c.share)) <= 0.73,
  message: "a mainland country is now above 73%",
)

#let ink = theme-minimal().at("ink", default: black)
#let island-colour = rgb("#d4580f")
#let near-colour = rgb("#2f74c0")
#let mainland-colour = rgb("#8b929c")
#let highlight = rgb("#1a9a6a")

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

#let kinds = ("Remote island", "Island near a mainland", "Mainland")
#let points = countries.map(c => (
  ..c,
  kind: if c.code in remote { kinds.at(0) } else if c.code in near { kinds.at(1) } else { kinds.at(2) },
  name: names.at(c.code, default: none),
))
#let breaks = (20, 50, 100, 200, 500, 1000)

#let kind-scale = scale-manual(values: (island-colour, near-colour, mainland-colour), limits: kinds)
#let labelled = remote + near + ("BR", "BO")

// Zoom links: from just right of each ringed point to the left edge of its panel.
// `link-end-x` sits one gutter past the right limit of the scatter, in species.
#let link-end-x = 2100
#let links = (
  (code: "MG", yend: 0.93),
  (code: "BO", yend: 0.30),
).map(l => {
  let c = country(l.code)
  (x: c.n * 1.12, y: c.share, yend: l.yend)
})

#let scatter = defer(
  plot,
  data: points,
  mapping: aes(x: "n", y: "share", colour: "kind", fill: "kind", shape: "kind", size: "kind"),
  layers: (
    geom-point(),
    geom-point(
      data: d => d.filter(c => c.code in ("MG", "BO")),
      size: 7.5pt,
      shape: "circle",
      fill: none,
      colour: highlight,
      stroke: 1pt,
    ),
    // Connectors from each ringed country to its zoom panel. They run past the
    // scatter panel (`clip: false`) into the gutter that holds the panels.
    ..links.map(l => annotate(
      "segment",
      x: l.x, y: l.y, xend: link-end-x, yend: l.yend,
      stroke: 0.7pt + highlight, clip: false,
    )),
    geom-text(
      data: d => d.filter(c => c.code in labelled),
      mapping: aes(label: "name"),
      font: sans,
      size: 6.5pt,
      colour: ink,
      repel: true,
      point-padding: 0.15,
      box-padding: 0.1,
      segment: true,
      segment-colour: ink.transparentize(40%),
    ),
  ),
  scales: scales(
    x: scale-continuous(transform: "log10", limits: (18, 1400), breaks: breaks, labels: breaks.map(str)),
    y: scale-continuous(limits: (0, 1), breaks: (0, 0.25, 0.5, 0.75, 1), labels: format-percent()),
    colour: kind-scale,
    fill: kind-scale,
    shape: scale-manual(values: ("circle", "diamond", "circle"), limits: kinds),
    size: scale-manual(values: (3.6pt, 3.8pt, 2.2pt), limits: kinds),
  ),
  guides: guides(default: none),
  labels: labels(x: "Native species in the country, log scale", y: "Found in no other country"),
)

#let bar-max = 340
#let bar-panel(title, sub, pairs, label-style: l => l) = {
  let rows = pairs.map(((k, v)) => (label: k, v: v))
  defer(
    plot,
    data: rows,
    mapping: aes(x: "label", y: "v"),
    layers: (
      // An invisible bar to the shared maximum: `limits` on a continuous y
      // with coord-flip() makes geom-col draw nothing, so this row trains the
      // scale instead and both panels keep one bar scale.
      geom-col(data: ((label: pairs.first().first(), v: bar-max),), fill: none, width: 0.8),
      geom-col(fill: highlight, width: 0.8),
      geom-text(mapping: aes(label: "v", nudge-y: 6), anchor: "west", font: sans, size: 6.5pt, colour: ink),
    ),
    scales: scales(
      x: scale-discrete(limits: rows.map(r => r.label), labels: label-style),
      y: scale-continuous(breaks: (), expand: (0%, 0%)),
    ),
    coord: coord-flip(),
    labels: labels(title: title, subtitle: sub, x: none, y: none),
  )
}

#let panel-theme = theme-minimal(
  plot-title: element-text(font: sans, size: 7.5pt, weight: "bold", colour: ink),
  plot-subtitle: element-text(font: sans, size: 6pt, colour: ink),
  plot-background: element-rect(fill: ink.transparentize(95%)),
  axis-text: element-text(font: sans, size: 6.5pt, colour: ink),
  panel-grid: element-blank(),
)

#compose(
  scatter,
  defer(
    compose,
    bar-panel(
      [#names.MG keeps #mg.only of its #mg.n species],
      [Its #mg.only species found in no other country, by family],
      mg-families,
      label-style: l => text(style: "italic", l),
    ),
    bar-panel(
      [#names.BO keeps only #bo.only of its #bo.n species],
      [How many of its species also live in each country],
      bo-shared.map(((c, v)) => (names.at(c), v)),
    ),
    columns: 1,
    theme: panel-theme,
  ),
  columns: 2,
  widths: (2.2, 1),
  guides: guides(default: none),
  labels: labels(
    title: [Remote Islands Keep Their Frogs to Themselves],
    subtitle: [
      Share of each country's native frog and toad species found in no other country, for the #countries.len() countries with #min-species or more species.
      #text(fill: island-colour, weight: "semibold")[Remote islands] (large circles) and #text(fill: near-colour, weight: "semibold")[islands near a mainland] (diamonds) against #text(fill: mainland-colour, weight: "semibold")[mainland countries] (small circles).
    ],
    caption: [
      Species count in each country, from the ISO codes AmphibiaWeb lists as native. \
      Source: AmphibiaWeb (TidyTuesday 2026-10-13). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
  ),
  theme: theme-minimal(
    plot-title: element-text(font: serif, size: 16pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: serif, size: 7.5pt, colour: ink),
    plot-caption: element-text(font: serif, size: 5.5pt, colour: ink.transparentize(30%)),
    axis-text: element-text(font: sans, size: 6pt, colour: ink.transparentize(25%)),
    axis-title: element-text(font: sans, size: 6.5pt, colour: ink),
    legend-text: element-text(font: sans, size: 6pt, colour: ink),
    legend-title: element-blank(),
    panel-grid-minor: element-blank(),
  ),
)
