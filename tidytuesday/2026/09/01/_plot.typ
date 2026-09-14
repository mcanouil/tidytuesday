// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per castle, fortress, palace or ruin listed on Wikidata, with its
// founding year where one is recorded.
// Source: data/world_castles.csv (TidyTuesday 2026-09-01).
#let landmarks = csv("data/world_castles.csv", row-type: dictionary)

#let comma = format-comma()

// The two groups the figure sets against each other. Castles and ruins are the
// fortified home, standing or fallen. Fortresses and palaces are the two
// buildings that replaced it, one for defence and one for living.
#let above = ("castle", "ruin")
#let below = ("fortress", "palace")

// Half-centuries, because a founding year is rarely exact and a century is too
// coarse to show the handover.
#let bin-width = 50
#let first-bin = 800
#let last-bin = 1900

#let year-of(row) = {
  let raw = row.at("year", default: "")
  if raw == "" or raw == "NA" { none } else { float(raw) }
}

// Only landmarks with a founding year inside the window are drawn. The years
// outside it are a scatter of ancient sites, too thin to bin.
#let dated = {
  landmarks
    .map(row => (
      category: row.category,
      year: year-of(row),
    ))
    .filter(row => row.year != none and row.year >= first-bin and row.year < last-bin + bin-width)
    .map(row => (
      ..row,
      bin: calc.floor(row.year / bin-width) * bin-width,
    ))
}

#let bins = range(first-bin, last-bin + bin-width, step: bin-width)
#let tally = count(dated, "bin", "category")
#let tally-at(bin, category) = {
  let hit = tally.find(t => t.bin == bin and t.category == category)
  if hit == none { 0 } else { hit.n }
}
#let total-in(categories) = dated.filter(row => row.category in categories).len()

// A merlon per half-century: the bar is narrower than the bin, so the top edge
// of each wall is a real crenellation and every notch counts 50 years.
#let merlon = 30
#let pad = (bin-width - merlon) / 2

#let median-year(category) = {
  let years = dated.filter(row => row.category == category).map(row => row.year).sorted()
  calc.round(years.at(calc.floor(years.len() / 2)))
}

// Castles stack up from the waterline, fortresses and palaces hang down from
// it. Each segment carries the running edge it starts at, so the two walls are
// built in one pass.
#let wall = {
  let out = ()
  for bin in bins {
    let edge = 0
    for category in above {
      let n = tally-at(bin, category)
      out.push((
        category: category,
        xmin: bin + pad,
        xmax: bin + pad + merlon,
        ymin: edge,
        ymax: edge + n,
      ))
      edge += n
    }
    edge = 0
    for category in below {
      let n = tally-at(bin, category)
      out.push((
        category: category,
        xmin: bin + pad,
        xmax: bin + pad + merlon,
        ymin: edge - n,
        ymax: edge,
      ))
      edge -= n
    }
  }
  out.filter(r => r.ymin != r.ymax)
}

#let sum-over(bin, categories) = categories.map(c => tally-at(bin, c)).sum()
#let keep-at(bin) = sum-over(bin, above)
#let split-at(bin) = sum-over(bin, below)

// The crest: the top edge of the upper wall, drawn as one path that climbs each
// merlon and drops back to the waterline between them. It traces the same
// counts the bars already carry, and it is what turns the skyline into
// battlements rather than a row of columns.
#let crest = {
  let out = ()
  for bin in bins {
    let h = keep-at(bin)
    out.push((x: bin + pad, y: 0))
    out.push((x: bin + pad, y: h))
    out.push((x: bin + pad + merlon, y: h))
    out.push((x: bin + pad + merlon, y: 0))
  }
  out
}

// The hinge the figure is about: the half-century where the two buildings that
// replaced the castle first take three quarters of the foundings.
#let hinge = 1650
#let share-at(bin) = split-at(bin) / (keep-at(bin) + split-at(bin))
#let peak-bin = bins.sorted(key: b => -keep-at(b)).first()

#assert(
  share-at(hinge - bin-width) < 0.5 and share-at(hinge) > 0.7,
  message: "the handover no longer falls in the " + str(hinge) + " half-century",
)
#assert(
  bins.filter(b => b >= hinge).all(b => share-at(b) > 0.7),
  message: "the share of fortresses and palaces falls back after " + str(hinge),
)

// Ink and paper come from the theme that typst-render resolved, so the figure
// follows the light and dark toggle of the site.
#let ink = theme-minimal().at("ink", default: black)
#let paper-colour = theme-minimal().at("paper", default: white)
#let note-colour = ink.transparentize(20%)
#let rule-colour = ink.transparentize(45%)

// Cinzel is cut from Roman inscriptional capitals, so the title reads as
// something carved rather than typed. Alegreya carries the prose, Alegreya Sans
// the axes. All three are vendored in assets/fonts, so CI renders them too.
#let title-font = "Cinzel"
#let body-font = "Alegreya"
#let axis-font = "Alegreya Sans"

// Above the waterline, one hue in two tones: the same building standing and
// fallen. Below it, two hues for two different buildings, blue against amber,
// the pair that survives every form of colour vision.
#let stone = rgb("#9a6a42")
#let weathered = rgb("#b9987a")
#let slate = rgb("#3f7d9c")
#let gilt = rgb("#c9962a")
#let water = rgb("#3f7d9c")

#let category-colours = (
  castle: stone,
  ruin: weathered,
  fortress: slate,
  palace: gilt,
)
#let category-order = ("castle", "ruin", "fortress", "palace")
#let category-scale = scale-discrete(
  limits: category-order,
  palette: category-order.map(c => category-colours.at(c)),
)

#let plural-of = (
  castle: "castles",
  ruin: "ruins",
  fortress: "fortresses",
  palace: "palaces",
)

#let note(body) = text(font: body-font, size: 7pt, fill: note-colour)[#body]
#let named(category, plural: true) = box(text(
  fill: category-colours.at(category),
  weight: "bold",
)[#if plural { plural-of.at(category) } else { category }])

#let chip(body, border: note-colour, width: auto) = box(
  fill: paper-colour,
  inset: (x: 4pt, y: 3pt),
  radius: 2pt,
  stroke: 0.5pt + border.transparentize(40%),
  width: width,
)[#body]

#let tag(category) = chip(
  border: category-colours.at(category),
  text(
    font: body-font,
    size: 7.5pt,
    fill: category-colours.at(category),
    weight: "bold",
  )[#upper(plural-of.at(category).first())#plural-of.at(category).slice(1)],
)

// The tags stand in the order the bars stack: ruins over castles above the
// waterline, fortresses over palaces below it. One row per tag, so the four
// stand as a single layer rather than as four single-row annotations.
#let tag-rows = (
  (category: "ruin", y: 130),
  (category: "castle", y: 96),
  (category: "fortress", y: -42),
  (category: "palace", y: -78),
).map(row => (x: 812, y: row.y, label: tag(row.category)))

// Counts read the same either side of the waterline, so the axis drops the sign
// and the two walls are compared directly.
#let unsigned = v => comma(calc.abs(v))

#plot(
  data: wall,
  mapping: aes(
    xmin: "xmin",
    xmax: "xmax",
    ymin: "ymin",
    ymax: "ymax",
    fill: "category",
  ),
  layers: (
    // The moat. A wash under the waterline, so the lower wall reads as the
    // reflection of the upper one rather than as a second chart. It is drawn as
    // a geom rather than an annotation, because `annotate` would file a fixed
    // colour as a fill value and train the discrete fill scale on it.
    geom-rect(
      data: ((xmin: first-bin - 20, xmax: last-bin + bin-width + 20, ymin: -215, ymax: 0),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      inherit-aes: false,
      fill: water,
      alpha: 0.1,
      stroke: none,
    ),
    // The handover, marked before the walls so the masonry sits over it.
    geom-vline(
      xintercept: hinge,
      colour: rule-colour,
      stroke: 0.7pt,
      linetype: "dashed",
    ),
    geom-rect(stroke: 0.4pt, colour: paper-colour),
    geom-path(
      data: crest,
      mapping: aes(x: "x", y: "y"),
      inherit-aes: false,
      colour: stone.darken(40%),
      stroke: 0.9pt,
    ),
    // The waterline. Everything below it is drawn as the castle's reflection,
    // which is where the two buildings it became are counted.
    geom-hline(yintercept: 0, colour: water, stroke: 1pt),
    annotate(
      "typst",
      x: first-bin + 10,
      y: 258,
      label: chip(width: 3.5cm, note[
        The medieval peak. In the half-century from #str(peak-bin), #comma(keep-at(peak-bin)) #named("castle") and #named("ruin") are founded against #comma(split-at(peak-bin)) #named("fortress") and #named("palace").
      ]),
      anchor: "north-west",
      clip: false,
    ),
    annotate(
      "typst",
      x: last-bin + bin-width - 10,
      y: 258,
      label: chip(width: 3.9cm, note[
        The handover. Up to #str(hinge), #named("fortress") and #named("palace") are #format-percent(digits: 0)(share-at(hinge - bin-width)) of new foundings. From #str(hinge) on they never fall below #format-percent(digits: 0)(0.75), and the fortified home never returns.
      ]),
      anchor: "north-east",
      clip: false,
    ),
    geom-typst(
      data: tag-rows,
      mapping: aes(x: "x", y: "y", label: "label"),
      inherit-aes: false,
      anchor: "west",
    ),
  ),
  scales: scales(
    x: scale-continuous(
      breaks: range(800, 2000, step: 100),
      labels: v => str(calc.round(v)),
      expand: (1%, 1%),
    ),
    y: scale-continuous(
      limits: (-215, 265),
      breaks: (-200, -100, 0, 100, 200),
      labels: unsigned,
      expand: (0%, 0%),
    ),
    fill: category-scale,
  ),
  guides: guides(default: none),
  labels: labels(
    title: "When the Castle Became Two Buildings",
    subtitle: [
      #comma(dated.len()) of the #comma(landmarks.len()) landmarks on Wikidata carry a founding year between #str(first-bin) and #str(last-bin + bin-width - 1), counted here by half-century. \
      Above the waterline, the fortified home: #comma(total-in(above)) #named("castle") and #named("ruin"). Below it, the two buildings that replaced it: #comma(total-in(below)) #named("fortress") and #named("palace"). \
      Each notch of the wall is fifty years. The median #named("castle", plural: false) here is founded in #str(median-year("castle")), the median #named("palace", plural: false) in #str(median-year("palace")).
    ],
    caption: [
      #comma(landmarks.len() - landmarks.filter(r => year-of(r) != none).len()) landmarks carry no founding year at all and are absent, and that gap is uneven: 77% of palaces are dated against 56% of castles, so the walls are a shape rather than a census. \
      A ruin is a state, not a purpose, and most ruins here are medieval castles; counting them above the waterline is the figure's choice, not the data's. \
      Source: Castlemap, from Wikidata (TidyTuesday 2026-09-01). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: "Landmarks founded per half-century",
    fill: none,
  ),
  theme: theme-minimal(
    plot-title: element-text(font: title-font, size: 16pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: axis-font, size: 8pt),
    axis-text: element-text(font: axis-font, size: 7pt),
    axis-ticks: element-tick(length: 0.05cm),
    panel-grid-minor: element-blank(),
    // A faint grid, so the wall stays a silhouette instead of a ruled chart.
    panel-grid-major: element-line(colour: ink.transparentize(88%), stroke: 0.4pt),
  ),
  width: 18cm,
  height: 9.45cm,
)
