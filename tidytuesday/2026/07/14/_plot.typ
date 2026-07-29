// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// importing it again here is redundant.
// #import "@preview/gribouille:0.6.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per museum specimen, covering the whole penguin family rather than
// the three species of palmerpenguins. Every number in the chart is derived
// from this table, so the figure is reproducible end to end: no hand-typed
// counts and no pre-summarised file.
// Source: data/many_penguins.csv (TidyTuesday 2026-07-14).
#let raw = csv("data/many_penguins.csv", row-type: dictionary)

// The CSV writes absent measurements as the literal string "NA"; parse those to
// none so a bird missing one measurement is dropped from this panel only.
#let num(v) = if v == none or v == "" or v == "NA" { none } else { float(v) }
#let round1(x) = calc.round(x, digits: 1)

// The three species of the palmerpenguins dataset, the ones nearly every
// teaching example plots. Here they are exactly the genus Pygoscelis.
#let palmer = ("P. adeliae", "P. antarcticus", "P. papua")

// Beak length against beak depth: the classic palmerpenguins axes, extended
// from three species to all eighteen. A bird missing either measurement carries
// no position on the panel, so it is dropped.
#let birds = ()
#for r in raw {
  let x = num(r.at("beak.length_culmen"))
  let y = num(r.at("beak.depth"))
  if x == none or y == none { continue }
  birds.push((x: x, y: y, species: r.shortname, genus: r.genus))
}

#let n-birds = birds.len()
#let n-species = birds.map(b => b.species).dedup().len()
#let n-genera = birds.map(b => b.genus).dedup().len()

#let famous = birds.filter(b => b.species in palmer)
#let others = birds.filter(b => b.species not in palmer)
#let n-famous = famous.len()
#let n-others = n-species - palmer.len()
// The title and the subtitle both call the palmerpenguins set "three", the one
// count that is spelled out rather than computed, so it is guarded here.
#assert(palmer.len() == 3, message: "the palmerpenguins set is no longer three species")

// The two bounding boxes the chart compares: the three famous species against
// the whole family. Their ratio is the headline number, computed rather than
// asserted, so it stays correct if the data changes.
#let span(rows, key) = {
  let v = rows.map(r => r.at(key))
  (lo: calc.min(..v), hi: calc.max(..v))
}
#let fam-x = span(birds, "x")
#let fam-y = span(birds, "y")
#let pal-x = span(famous, "x")
#let pal-y = span(famous, "y")
#let frac-x = (pal-x.hi - pal-x.lo) / (fam-x.hi - fam-x.lo)
#let frac-y = (pal-y.hi - pal-y.lo) / (fam-y.hi - fam-y.lo)
#let pct-x = calc.round(100 * frac-x)
#let pct-y = calc.round(100 * frac-y)
#let pct-box = calc.round(100 * frac-x * frac-y)
// How far past the famous three the rest of the family reaches, at each extreme.
#let mult-x = calc.round(fam-x.hi / pal-x.hi, digits: 1)
#let mult-y = calc.round(fam-y.hi / pal-y.hi, digits: 1)

// The family extremes the chart calls out by name, found by measurement rather
// than by row position, so they stay correct if the data changes.
#let by-length = birds.sorted(key: b => b.x)
#let longest = by-length.last()
#let shortest = by-length.first()
#let deepest = birds.sorted(key: b => b.y).last()

// One palette, one source of truth. The three famous species each take a hue;
// everything else in the family is a deliberate neutral, a backdrop rather than
// a category. Shape repeats the same split, so identity never rests on colour.
//
// Every hue here clears the colour-vision and contrast checks against the pale
// page and the dark one alike, so the figure needs no light/dark branch and
// nothing outside this file has to tell it which page it is on.
#let adelie-col = rgb("#e4572e") // warm coral
#let chinstrap-col = rgb("#17a398") // teal
#let gentoo-col = rgb("#4176d8") // deep blue
#let other-col = rgb("#8a8f96") // the other species, held back
#let box-col = rgb("#a86a44") // warm brown, for the box tracing the famous three
// A dark seam rather than a white one: at this opacity it separates overlapping
// marks on the pale page without cutting a bright hole in the dark one.
#let mark-edge = rgb("#33333366")

// A scholarly serif for a museum specimen table, with its sans companion for
// the running text. Both are vendored in assets/fonts, so CI renders them too.
#let body-font = "Alegreya Sans"
#let chart-font = "Alegreya"

#let famous-colours = (adelie-col, chinstrap-col, gentoo-col)
#let famous-shapes = ("circle", "triangle", "square")

// No fill means "say nothing about the colour", so the text inherits the page
// ink and stays legible whichever way the site is toggled. A colour is passed
// only for text naming a coloured mark; secondary text steps down in size.
//
// Species names are binomials, so they are set in italic wherever they appear.
#let sp(name, fill: none, size: 8pt, weight: "regular") = {
  set text(fill: fill) if fill != none
  text(font: chart-font, style: "italic", size: size, weight: weight)[#name]
}
#let note(body, fill: none, size: 7pt, weight: "regular") = {
  set text(fill: fill) if fill != none
  text(font: body-font, size: size, weight: weight)[#body]
}

// The three clouds overlap almost completely, so a label per cloud would sit on
// top of its neighbours; the legend goes in the empty band below them instead.
// Both scales carry the same labels so the fill and shape guides merge into one
// key, which then draws the real marker rather than a lookalike glyph.
#let famous-labels = palmer.map(name => sp(name, size: 8.5pt, weight: "bold")
  + note(size: 6.5pt)[ n = #famous.filter(b => b.species == name).len()])
#let famous-scale(values) = scale-discrete(
  limits: palmer, palette: values, labels: famous-labels,
)

// A named specimen at one edge of the family, with the measurement that puts it
// there, so the reader can see what the famous three leave out at either end.
#let edge(b, value) = sp(b.species, size: 7.5pt) + note(size: 6.5pt)[ · #value]

#plot(
  data: birds,
  mapping: aes(x: "x", y: "y"),
  layers: (
    // The whole family as one faint envelope, so the reader sees the shape of
    // the space before reading the points inside it.
    geom-mark(
      method: "hull", expand: 6pt,
      fill: other-col, colour: other-col, alpha: 0.1, stroke: 0.5pt,
    ),
    // The fifteen species nobody plots: small, translucent and held to a
    // neutral, so they read as context rather than as a fourth category.
    geom-point(
      data: others,
      size: 2.2pt, fill: other-col, colour: mark-edge, stroke: 0.4pt, alpha: 0.85,
    ),
    // The box the whole figure is about: the range the three famous species
    // cover, drawn over the family it is a small corner of. The dash rides on
    // the Typst stroke rather than on `linetype:`, which geom-rect has no
    // parameter for and which annotate would swallow as an aesthetic.
    annotate(
      "rect",
      xmin: pal-x.lo, xmax: pal-x.hi, ymin: pal-y.lo, ymax: pal-y.hi,
      fill: none, colour: box-col, clip: false,
      stroke: (paint: box-col, thickness: 1.1pt, dash: "dashed"),
    ),
    // The famous three, each with its own hue and its own shape.
    geom-point(
      data: famous, mapping: aes(fill: "species", shape: "species"),
      size: 3.6pt, colour: mark-edge, stroke: 0.6pt,
    ),
    // The family extremes, each anchored away from its own point so the label
    // never covers the specimen it names.
    annotate("typst", x: deepest.x, y: deepest.y + 0.5, label: edge(deepest, [#round1(deepest.y) mm deep]), anchor: "south", clip: false),
    annotate("typst", x: longest.x, y: longest.y - 1.1, label: edge(longest, [#round1(longest.x) mm long]), anchor: "north-east", clip: false),
    annotate("typst", x: shortest.x, y: shortest.y - 0.4, label: edge(shortest, [#round1(shortest.x) mm long]), anchor: "north-west", clip: false),
    // One callout in the empty upper-right quadrant, tying the dashed box to
    // the number it stands for without landing on any data.
    annotate(
      "typst", x: fam-x.hi, y: fam-y.hi + 1.4,
      label: box(width: 5.4cm)[
        #set align(right)
        #note(fill: box-col, size: 7.5pt, weight: "bold")[
          The dashed box holds every beak the three famous species have between
          them: #pct-x% of the family's range in length and #pct-y% of it in
          depth, roughly #pct-box% of the area the other #n-others species fill.
        ]
      ],
      anchor: "north-east", clip: false,
    ),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Beak Length, Culmen (mm)",
      breaks: (40, 50, 60, 70, 80, 90, 100, 110),
      expand: (3%, 3%),
    ),
    y: scale-continuous(
      name: "Beak Depth (mm)",
      breaks: (10, 15, 20, 25, 30),
      expand: (5%, 12%),
    ),
    fill: famous-scale(famous-colours),
    shape: famous-scale(famous-shapes),
  ),
  // The key sits inside the panel, in the empty band under the three clouds.
  guides: guides(default: guide-legend(position: (x: 82%, y: 78%), key-size: 0.22cm)),
  labels: labels(
    title: "The Famous Three Penguins Sit in One Corner of the Beak",
    // The legend names the species; a title over it would only repeat the word.
    fill: none,
    shape: none,
    subtitle: [
      Measure all #n-species species instead of the usual three, and the
      palmerpenguins trio,
      #text(fill: adelie-col, weight: "bold")[Adélie],
      #text(fill: chinstrap-col, weight: "bold")[chinstrap] and
      #text(fill: gentoo-col, weight: "bold")[gentoo], turns out to hold one
      small patch of the family's beak shapes. The
      #text(fill: other-col, weight: "bold")[other #n-others species]
      reach beaks #mult-x times longer and #mult-y times deeper than anything
      the famous three offer.
    ],
    caption: typst([
      #n-birds museum specimens carrying both beak measurements, #n-species species across #n-genera genera; #n-famous of them belong to the palmerpenguins three. \
      Beak length is measured along the culmen. Birds missing either measurement are excluded, and the sexes are pooled. \
      Source: Many Penguins dataset (TidyTuesday 2026-07-14). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7.5pt),
    panel-grid-minor: element-blank(),
  ),
  width: auto,
  height: auto,
)
