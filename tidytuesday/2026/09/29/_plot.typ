// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per urban centre: its population in 2025 and the hospitals and
// pharmacies found in it in 2024. The facilities come from open map data, so a
// count is what was mapped, not what exists.
// Source: data/health.csv (TidyTuesday 2026-09-29).
#let records = csv("data/health.csv", row-type: dictionary)

// The yardstick: 20,242 pharmacies in France on 1 January 2025 (Ordre national
// des pharmaciens) for 68.6 million people (INSEE).
#let national-rate = 20242 / 68.6e6 * 1e5

#let top-n = 20
#let cities = {
  records
    .filter(r => r.GC_CNT_GAD_2025 == "France")
    .sorted(key: r => -float(r.GC_POP_TOT_2025))
    .slice(0, top-n)
    .map(r => (
      city: r.GC_UCN_MAI_2025,
      near: float(r.HL_SHP_PHA_2025),
      rate: int(r.HL_FCL_PHA_2024) / float(r.GC_POP_TOT_2025) * 1e5,
    ))
    .sorted(key: c => c.rate)
}

// The claim the title makes: on the map, Lille has the most pharmacies per
// person of the largest French cities, and about seven times as many as Paris.
#let lille = cities.find(c => c.city == "Lille")
#let paris = cities.find(c => c.city == "Paris")
#assert(cities.last().city == "Lille", message: "Lille is no longer the best-mapped large French city")
#assert(lille.rate / paris.rate >= 7, message: "Lille no longer has seven times the mapped pharmacies of Paris")
#assert(cities.all(c => c.rate < national-rate), message: "a city now reaches the national rate")

// Ink and paper come from the theme that typst-render resolved, so the figure
// follows the light and dark toggle of the site. The green of the French
// pharmacy cross marks what was mapped and a warm grey hatch what was not; the
// green is mixed a quarter towards the ink so it keeps its contrast on both.
#let ink = theme-minimal().at("ink", default: black)
#let paper = theme-minimal().at("paper", default: white)
#let cross = color.mix((rgb("#0b9a52"), 75%), (ink, 25%))
#let gap = rgb("#a89c84")

// Spectral comes from Production Type, a Paris foundry; IBM Plex Sans keeps
// the small labels plain. Both, and the emoji font, are vendored in assets/fonts.
#let title-font = "Spectral"
#let body-font = "IBM Plex Sans"
#let emoji-font = "Noto Color Emoji"

#let hatch = tiling(size: (4pt, 4pt))[
  #place(line(start: (0%, 100%), end: (100%, 0%), stroke: 0.6pt + gap))
]

#let rate-label = format-number(digits: 1)
#let share-label = format-number(digits: 0, suffix: "%")
#let highlighted = ("Lille", "Paris")

// Rows are numbered from the bottom, so the best-mapped city sits at the top.
#let rows = cities.enumerate().map(((i, c)) => (..c, row: i + 1))
#let half = 0.2

#let stems = rows.map(c => (x: 0, xend: c.rate, y: c.row, yend: c.row))
#let gaps = rows.map(c => (
  xmin: c.rate,
  xmax: national-rate,
  ymin: c.row - half,
  ymax: c.row + half,
))
#let pills = rows.map(c => (x: c.rate, y: c.row, content: text(font: emoji-font)[💊]))

#let strong(c, body) = if c.city in highlighted { text(weight: "bold", body) } else { body }
#let names = rows.map(c => (
  x: -0.6,
  y: c.row,
  content: text(font: body-font, size: 6.5pt, fill: ink)[#strong(c, c.city)],
))
#let values = rows.map(c => (
  x: c.rate + 1,
  y: c.row,
  content: box(fill: paper, inset: 1pt, text(font: body-font, size: 5.5pt, fill: cross)[#strong(c, rate-label(c.rate))]),
))

// The second fact, in a column of its own: how many people live within 1 km of
// a mapped pharmacy. It reads the same bias as the count.
#let near-x = national-rate + 4.5
#let nears = rows.map(c => (
  x: near-x,
  y: c.row,
  content: text(font: body-font, size: 6pt, fill: ink.transparentize(25%))[#strong(c, share-label(c.near))],
))

#let top = rows.len() + 1.1
#let headers = (
  (
    x: national-rate,
    y: top,
    content: text(font: body-font, size: 6pt, fill: ink)[France: #rate-label(national-rate)],
  ),
  (
    x: near-x,
    y: top,
    content: align(center, text(font: body-font, size: 6pt, fill: ink)[within 1 km \ of a pharmacy]),
  ),
)

#plot(
  data: rows,
  mapping: aes(x: "x", y: "y"),
  layers: (
    geom-rect(
      data: gaps,
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      inherit-aes: false,
      fill: hatch,
    ),
    geom-segment(
      data: ((x: national-rate, xend: national-rate, y: 0.5, yend: top),),
      mapping: aes(xend: "xend", yend: "yend"),
      colour: ink,
      stroke: 0.6pt,
      linetype: "dashed",
    ),
    geom-segment(
      data: stems,
      mapping: aes(xend: "xend", yend: "yend"),
      colour: cross,
      stroke: 1.2pt,
    ),
    geom-typst(data: pills, mapping: aes(label: "content"), size: 9pt),
    geom-typst(data: names, mapping: aes(label: "content"), anchor: "east"),
    geom-typst(data: values, mapping: aes(label: "content"), anchor: "west"),
    geom-typst(data: nears, mapping: aes(label: "content"), anchor: "center"),
    geom-typst(data: headers, mapping: aes(label: "content"), anchor: "south"),
  ),
  scales: scales(
    x: scale-continuous(
      limits: (-6.5, near-x + 2.5),
      breaks: (0, 10, 20),
      expand: (0%, 0%),
    ),
    y: scale-continuous(limits: (0.4, top + 1.6), breaks: (), expand: (0%, 0%)),
  ),
  guides: guides(default: none),
  labels: labels(
    title: [On the Map, Lille Has Seven Times the Pharmacies of Paris],
    subtitle: [
      #text(font: emoji-font)[💊] Pharmacies per 100,000 people in the #top-n largest French cities, counted from open map data in 2024. \
      #text(fill: cross, weight: "semibold")[Lille: #rate-label(lille.rate)], #text(fill: cross, weight: "semibold")[Paris: #rate-label(paris.rate)], France: #rate-label(national-rate) (dashed line). #box(width: 1.6em, height: 0.8em, fill: hatch, stroke: 0.4pt + gap) Pharmacies missing from the map.
    ],
    caption: [
      A pharmacy counts only where someone mapped it, so a ranking by pharmacies per person ranks the mappers. City boundaries follow the Degree of Urbanisation, not the commune. \
      National rate: 20,242 pharmacies on 1 January 2025 (Ordre national des pharmaciens) for 68.6 million people (INSEE). \
      Source: European Commission JRC, GHS Urban Centre Database 2025 (TidyTuesday 2026-09-29). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: none,
  ),
  theme: theme-minimal(
    plot-title: element-text(font: title-font, size: 16pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: body-font, size: 7.5pt, colour: ink),
    plot-caption: element-text(font: body-font, size: 5.5pt, colour: ink.transparentize(30%)),
    axis-text: element-text(font: body-font, size: 6pt, colour: ink.transparentize(30%)),
    panel-grid: element-blank(),
  ),
  width: auto,
  height: auto,
)
