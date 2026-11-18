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

// The first level of a discrete y axis sits at the bottom, and `cities` runs
// from the lowest rate up, so the best-mapped city sits at the top.
#let near-x = national-rate + 5.5
#let emphasise(c, body) = if c.city in highlighted { strong(body) } else { body }
#let rows = cities.map(c => (
  ..c,
  zero: 0,
  national: national-rate,
  value: emphasise(c, rate-label(c.rate)),
  value-x: c.rate + 0.6,
  near-label: emphasise(c, share-label(c.near)),
  near-x: near-x,
  pill: "💊",
))

#let plot-layers = (
  geom-vline(xintercept: national-rate, colour: ink, stroke: 0.6pt, linetype: "dashed"),
  // The gap to the national rate, drawn as a hatched segment.
  geom-segment(mapping: aes(x: "rate", xend: "national"), colour: hatch, stroke: 5pt),
  geom-segment(colour: cross, stroke: 1.2pt),
  geom-text(mapping: aes(x: "rate", label: "pill"), font: emoji-font, size: 9pt),
  geom-label(
    mapping: aes(x: "value-x", label: "value"),
    font: body-font,
    size: 5.5pt,
    colour: cross,
    fill: paper,
    stroke: none,
    inset: 1pt,
    anchor: "west",
  ),
  geom-text(
    mapping: aes(x: "near-x", label: "near-label"),
    font: body-font,
    size: 6pt,
    colour: ink.transparentize(25%),
  ),
)

#plot(
  data: rows,
  mapping: aes(x: "zero", xend: "rate", y: "city", yend: "city"),
  layers: plot-layers,
  scales: scales(
    x: scale-continuous(
      limits: (0, near-x + 2.5),
      breaks: (0, 10, 20),
      secondary: sec-axis(
        breaks: (national-rate, near-x),
        labels: ([France: #rate-label(national-rate)], align(center)[within 1 km \ of a pharmacy]),
      ),
      expand: (0%, 0%),
    ),
    y: scale-discrete(limits: cities.map(c => c.city), labels: l => if l in highlighted { text(weight: "bold")[#l] } else { l }),
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
