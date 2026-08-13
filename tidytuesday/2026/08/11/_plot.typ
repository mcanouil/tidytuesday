// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// importing it again here is redundant.
// #import "@preview/gribouille:0.6.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per galaxy: the Palomar spectroscopic survey of nearby bright
// galaxies, with the emission-line ratios each nucleus was classified from and
// the class Ho, Filippenko and Sargent settled on.
//
// The four ratio columns are misnamed. `log_oiii_hb` and its siblings hold the
// plain ratio, not its logarithm: IC 10 carries 4.35, and its `oiii_5007` over
// `h_beta` in the emission-line table is 0.35 / 0.08. So every axis here takes
// the logarithm itself, and reading the columns as their names claim would put
// the whole figure on the wrong scale. No value in any of the four is zero or
// negative, so the logarithm is safe on every row.
//
// The week's second table, data/palomar_emission_lines.csv, is the line
// strengths those ratios are built from; it is left alone because the ratios
// are what the classification is made of and the survey table already carries
// them.
// Source: data/palomar_survey.csv (TidyTuesday 2026-08-11).
#let raw = csv("data/palomar_survey.csv", row-type: dictionary)

#let pct1 = format-percent(digits: 1)
#let dp2 = format-number(digits: 2)

// `NA` is pervasive across every ratio column and across the class itself, so
// missingness is turned into `none` once and filtered on once.
#let num(v) = if v == none or v == "" or v == "NA" { none } else { float(v) }

// The four classes the survey's nuclei are sorted into, ordered by how much of
// the ionisation is stellar rather than accretion-driven. One further galaxy is
// classed as pure absorption and 71 carry no class at all; both are dropped,
// and the caption says so.
#let class-order = ("H II", "Transition", "LINER", "Seyfert")

// The pair the figure is about takes the two best-separated hues: amber against
// blue is the strongest pairing available here, at a worst-case colour-vision
// distance of 23.4 across deuteranopia, protanopia and tritanopia. That leaves
// green against blue as the weakest pair at 5.6 under tritanopia, and it falls
// on H II against LINER, which are the two classes furthest apart in the data
// and further separated by shape and by where they sit on the panel. All four
// clear the colour-vision and contrast checks on the pale page and the dark one
// alike, so the figure needs no light/dark branch.
#let class-colours = (
  "H II": rgb("#3aa270"),
  "Transition": rgb("#c47a12"),
  "LINER": rgb("#2f7fc4"),
  "Seyfert": rgb("#b03e5c"),
)
// Colour is doubled by shape on the scatter, so no reader has to tell two
// classes apart by hue alone.
#let class-shapes = (
  "H II": "circle",
  "Transition": "triangle",
  "LINER": "square",
  "Seyfert": "diamond",
)

// One pass over the 486 rows. A galaxy is drawn only if it carries a class and
// all three ratios the figure uses, so both panels describe exactly the same
// set of galaxies and the counts in the subtitle mean the same thing on each.
#let galaxies = ()
#let n-unclassified = 0
#let n-absorption = 0
#let n-incomplete = 0
#for r in raw {
  if r.activity_type == "NA" {
    n-unclassified += 1
    continue
  }
  if r.activity_type == "Absorption" {
    n-absorption += 1
    continue
  }
  let oiii = num(r.log_oiii_hb)
  let nii = num(r.log_nii_ha)
  let oi = num(r.log_oi_ha)
  if oiii == none or nii == none or oi == none {
    n-incomplete += 1
    continue
  }
  galaxies.push((
    galaxy: r.galaxy_name,
    class: r.activity_type,
    oiii: calc.log(oiii),
    nii: calc.log(nii),
    oi: calc.log(oi),
    confidence: r.classification_confidence,
  ))
}

#let class-counts = class-order.map(c => (
  class: c,
  n: galaxies.filter(g => g.class == c).len(),
))
#let count-of(c) = class-counts.find(k => k.class == c).n

// The title spells out sixty-two, the one number in this figure that is not
// computed into the words around it, so a change upstream fails the render
// rather than quietly contradicting the headline.
#assert(
  count-of("Transition") == 62,
  message: "the data no longer holds sixty-two drawable transition objects",
)
#assert(
  galaxies.len() == class-counts.map(k => k.n).sum(),
  message: "a galaxy carries a class outside the four the figure draws",
)

// How well one vertical cut on a single ratio tells a LINER from a transition
// object: the whole point of the figure, so it is measured rather than asserted.
//
// A sweep over the sorted values rather than a pair of nested loops: every
// candidate cut is the midpoint between two neighbours, and the running counts
// give its accuracy in one pass. Galaxies at or above the cut are called LINER.
#let best-cut(sample, key) = {
  let sorted = sample.sorted(key: g => (key)(g))
  let n-liner = sorted.filter(g => g.class == "LINER").len()
  // The cut below everything calls every galaxy a LINER, and is the baseline
  // any real cut has to beat.
  let best = (cut: (key)(sorted.first()), correct: n-liner)
  let below-liner = 0
  let below-other = 0
  for (i, g) in sorted.enumerate() {
    if g.class == "LINER" { below-liner += 1 } else { below-other += 1 }
    let correct = below-other + n-liner - below-liner
    if correct > best.correct {
      let here = (key)(g)
      let next = if i + 1 < sorted.len() { (key)(sorted.at(i + 1)) } else { here }
      best = (cut: (here + next) / 2, correct: correct)
    }
  }
  best + (n: sorted.len(), accuracy: best.correct / sorted.len())
}

#let pair = galaxies.filter(g => g.class in ("LINER", "Transition"))
#let nii-cut = best-cut(pair, g => g.nii)
#let oi-cut = best-cut(pair, g => g.oi)

// The figure only says something if the two diagnostics really do disagree.
#assert(
  oi-cut.accuracy > nii-cut.accuracy + 0.2,
  message: "the two diagnostics no longer disagree enough to be worth a figure",
)

// How many transition objects the [N II] cut hands to the LINER side: the
// sentence the left panel exists to make.
#let strays = pair.filter(g => g.class == "Transition" and g.nii >= nii-cut.cut).len()

#let n-very-uncertain = galaxies.filter(g => g.confidence == "very uncertain").len()

// The rules, the notes beside them and the page the key sits on all come from
// the theme the typst-render inputs resolved, so they follow the site's light
// and dark toggle without a branch; the alpha is what holds the rules behind
// the marks.
#let ink = theme-minimal().at("ink", default: black)
#let paper-colour = theme-minimal().at("paper", default: white)
#let rule-colour = ink.transparentize(30%)
#let note-colour = ink.transparentize(20%)

// A signage grotesque for the headings and a warm text face for the prose. Both
// are vendored in assets/fonts, so CI renders them too.
#let body-font = "Lato"
#let chart-font = "Archivo"

#let panel-theme = theme-minimal(
  legend-background: element-rect(fill: paper-colour),
  axis-title: element-text(font: body-font, size: 8pt),
  axis-text: element-text(font: body-font, size: 7pt),
  legend-text: element-text(font: body-font, size: 7pt),
  axis-ticks: element-tick(length: 0.05cm),
)

// The note that sits beside each rule, in the theme's own ink so it tracks the
// page rather than fighting it.
#let note(body) = text(font: body-font, size: 6.5pt, fill: note-colour)[#body]

#let class-scale = scale-discrete(
  limits: class-order,
  palette: class-order.map(c => class-colours.at(c)),
)
#let shape-scale = scale-manual(
  limits: class-order,
  values: class-order.map(c => class-shapes.at(c)),
)

// Boxed so a class never breaks across a line: "H II" arriving as "H" at the end
// of one line and "II" at the start of the next reads as two different things.
#let coloured(name) = box(text(fill: class-colours.at(name), weight: "bold")[#name])

// The panel on the left: the diagram every paper draws, with the cut that does
// best on it. The key sits in the bottom left, the one corner of this panel no
// galaxy reaches.
#let bpt-panel = defer(
  plot,
  data: galaxies,
  mapping: aes(x: "nii", y: "oiii", colour: "class", fill: "class", shape: "class"),
  layers: (
    geom-vline(xintercept: nii-cut.cut, colour: rule-colour, stroke: 0.7pt, linetype: "dashed"),
    geom-point(size: 2pt, alpha: 0.75, stroke: 0.4pt),
    annotate(
      "typst",
      x: nii-cut.cut,
      y: 1.5,
      label: note[Best cut here, #pct1(nii-cut.accuracy) right #sym.arrow.r],
      anchor: "east",
      clip: false,
    ),
  ),
  scales: scales(
    x: scale-continuous(breaks: (-1.5, -1, -0.5, 0, 0.5), expand: (6%, 6%)),
    y: scale-continuous(breaks: (-1, -0.5, 0, 0.5, 1), expand: (6%, 6%)),
    colour: class-scale,
    fill: class-scale,
    shape: shape-scale,
  ),
  // One key for three aesthetics: colour, fill and shape describe the same four
  // classes, so they are given the same guide and merge into a single set of
  // swatches that look like the marks on the panel rather than three stacks of
  // them. It has no title because the subtitle already names what the colours
  // are, and it sits on the theme's own page colour so the grid does not show
  // through it.
  guides: guides(default: guide-legend(position: bottom + left, key-size: 0.3cm)),
  labels: labels(
    x: typst[log #box[[N II] $lambda 6583$] / H$alpha$],
    y: typst[log #box[[O III] $lambda 5007$] / H$beta$],
    colour: none,
    fill: none,
    shape: none,
  ),
  theme: panel-theme,
  width: 11.4cm,
  height: 6.2cm,
)

// The panel on the right: the same galaxies, the same classes, one ratio
// swapped. Densities rather than a second scatter, because four hundred points
// at a third of the width is a smudge and the thing worth seeing is where each
// class sits and how far it overlaps the next. Reversed so the classes read top
// to bottom in the order of the key on the left.
#let oi-panel = defer(
  plot,
  data: galaxies,
  mapping: aes(x: "oi", y: "class", colour: "class", fill: "class"),
  layers: (
    geom-vline(xintercept: oi-cut.cut, colour: rule-colour, stroke: 0.7pt, linetype: "dashed"),
    geom-density-ridges(scale: 1.5, alpha: 0.7, stroke: 0.6pt),
    annotate(
      "typst",
      x: oi-cut.cut,
      y: 4.85,
      label: note[#pct1(oi-cut.accuracy) right],
      anchor: "west",
      clip: false,
    ),
  ),
  scales: scales(
    x: scale-continuous(breaks: (-3, -2, -1, 0), expand: (4%, 4%)),
    y: scale-discrete(limits: class-order.rev(), expand: (14%, 24%)),
    colour: class-scale,
    fill: class-scale,
  ),
  guides: guides(default: none),
  labels: labels(
    x: typst[log #box[[O I] $lambda 6300$] / H$alpha$],
    y: none,
  ),
  theme: panel-theme,
  width: 5.7cm,
  height: 6.2cm,
)

#compose(
  bpt-panel,
  oi-panel,
  columns: 2,
  widths: (2, 1),
  gutter: 0cm,
  labels: labels(
    title: "Sixty-Two Galaxies Hide in the Diagram Everyone Draws",
    subtitle: [
      One mark per galaxy, #galaxies.len() nearby nuclei from the Palomar survey, coloured and shaped by the class the survey gave them.
      On the left, the diagram every paper draws, where #coloured("Transition") objects sit inside the #coloured("LINER") cloud rather than beside it: the best vertical cut anywhere on it still
      hands #strays of the #count-of("Transition") to the wrong side. On the right, the same galaxies against one different ratio, where the two part at #pct1(oi-cut.accuracy).
      #coloured("H II") nuclei and #coloured("Seyfert") ones were never the hard case.
    ],
    caption: typst([
      #galaxies.len() galaxies carry a class and all three ratios; #n-unclassified carry no class, #n-absorption is absorption only, #n-incomplete lack a ratio. The `log_` columns hold the ratio, not its logarithm. \
      Accuracy is the best single cut separating the #pair.len() LINERs and transition objects, at log [N II]/H#sym.alpha #sym.eq #dp2(nii-cut.cut) and log [O I]/H#sym.alpha #sym.eq #dp2(oi-cut.cut)#[;] #n-very-uncertain of them are flagged very uncertain. \
      The survey defined transition objects on [O I]/H#sym.alpha, so the right panel partly marks its own homework. Source: Palomar survey (TidyTuesday 2026-08-11). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
  ),
  width: 18cm,
  height: 9.45cm,
)
