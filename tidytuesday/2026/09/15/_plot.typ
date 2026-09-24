// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per manuscript in the Leon Levy Dead Sea Scrolls Digital Library,
// with the composition it copies and whether that composition entered the
// Hebrew Bible.
// Source: data/dead_sea_scrolls.csv (TidyTuesday 2026-09-15).
#let manuscripts = csv("data/dead_sea_scrolls.csv", row-type: dictionary)

// A composition copied on papyrus, in the old Hebrew script, or in Greek
// carries a prefix (papGenesis, paleoExodus, LXXLeviticus), and a copy the
// editors are unsure of ends in a question mark. Stripping both leaves the work
// itself, so every copy of Exodus is counted as Exodus.
#let work-of(composition) = {
  composition.trim("?", at: end).replace(regex("^(pap)?(paleo)?(LXX)?"), "")
}

// Labels that name a kind of text rather than a work: phylacteries and mezuzot
// are ritual objects, and the rest are the catalogue's words for fragments it
// could not tie to one composition.
#let not-a-work = (
  "NA",
  "Unidentified",
  "Multiple Compositions",
  "Phylacteries",
  "Mezuzah",
  "Account",
  "Narrative",
  "Prayer",
)

#let copies = {
  manuscripts
    .map(row => (
      work: work-of(row.composition),
      doubtful: row.composition.ends-with("?"),
      canonical: row.canon_status in ("Protocanonical", "Deuterocanonical"),
    ))
    .filter(row => row.work not in not-a-work)
}

// Every work drawn, with its certain and doubtful copies. The figure keeps the
// works with at least eight certain copies: below that the rows run into dozens
// of works with a handful each, and the comparison the title makes is lost.
#let min-copies = 8

// The catalogue files the odd copy of a work under another status: one Daniel
// as outside the canon, one certain Psalms under Sirach and one doubtful Psalms
// outside the canon. A work takes the status of most of its copies.
#let works = {
  let tally = (:)
  for row in copies {
    let t = tally.at(row.work, default: (sure: 0, doubtful: 0, in-canon: 0))
    if row.doubtful { t.doubtful += 1 } else { t.sure += 1 }
    if row.canonical { t.in-canon += 1 }
    tally.insert(row.work, t)
  }
  tally
    .pairs()
    .map(((name, t)) => (
      work: name,
      sure: t.sure,
      doubtful: t.doubtful,
      canonical: 2 * t.in-canon > t.sure + t.doubtful,
    ))
    .filter(w => w.sure >= min-copies)
    .sorted(key: w => (-w.sure, w.work))
}

#let work-at(name) = {
  let hit = works.find(w => w.work == name)
  assert(hit != none, message: "no longer drawn: " + name)
  hit
}

// The claim the title makes: a book that did not enter the canon was copied as
// often as one of the five books of Moses.
#assert(
  work-at("Jubilees").sure == work-at("Exodus").sure,
  message: "Jubilees and Exodus no longer have the same number of certain copies",
)
#assert(
  not work-at("Jubilees").canonical and work-at("Exodus").canonical,
  message: "Jubilees and Exodus no longer sit on either side of the canon",
)

// The catalogue's names are editorial shorthand. These are the names a reader
// knows the works by.
#let display = (
  "Enoch": "1 Enoch",
  "Enoch, Book of Giants": "Book of Giants",
  "Songs of the Sabbath Sacrifice": "Sabbath Songs",
)

// Iron-gall ink and red ochre on parchment: the two inks the scribes had. The
// scroll is a physical object, so the page keeps its colours on the light and
// the dark site theme alike.
#let parchment = rgb("#e8dbbd")
#let ink = rgb("#2a1f17")
#let rubric = rgb("#a3321f")

// Frank Ruhl Libre, for the title, was drawn for Hebrew and Latin together, and
// Alegreya Sans keeps the calligraphic stroke at label size. Both are vendored
// in assets/fonts.
#let body-font = "Alegreya Sans"

#let ink-of(w) = if w.canonical { ink } else { rubric }

// Rows are numbered from the bottom, so the most copied work sits at the top,
// and the two rows the title compares are marked once here.
#let rows = {
  works
    .enumerate()
    .map(((i, w)) => (..w, row: works.len() - i, strong: w.work in ("Jubilees", "Exodus")))
}

// One tile per manuscript, laid left to right along the work's row: certain
// copies first, doubtful ones after them as outlines only. The headline rows
// are drawn at full strength and every other row is faded, so the eye goes to
// the two rows the title compares.
#let tile-width = 0.78
#let tile-height = 0.6

#let tiles = {
  rows
    .map(w => range(w.sure + w.doubtful).map(k => (
      x: k + 1,
      y: w.row,
      doubtful: k >= w.sure,
      paint: ink-of(w),
      strength: if w.strong { 1 } else { 0.7 },
    )))
    .flatten()
}

// Name on the left, in italic when the work is outside the canon, so the
// distinction does not rest on the red alone. Count on the right, at the end
// of the certain copies.
#let name-rows = rows.map(w => (
  x: 0.2,
  y: w.row,
  content: text(
    font: body-font,
    size: 7.5pt,
    weight: if w.strong { "bold" } else { "regular" },
    style: if w.canonical { "normal" } else { "italic" },
    fill: ink-of(w),
  )[#display.at(w.work, default: w.work)],
))

#let count-rows = rows.map(w => (
  x: w.sure + w.doubtful + 0.7,
  y: w.row,
  content: text(
    font: body-font,
    size: 7pt,
    weight: if w.strong { "bold" } else { "regular" },
    fill: ink.transparentize(if w.strong { 0% } else { 25% }),
  )[#str(w.sure)#if w.doubtful > 0 { " (+" + str(w.doubtful) + "?)" }],
))

#let as-ink(body, paint) = box(text(fill: paint, weight: "bold")[#body])

#plot(
  data: tiles,
  mapping: aes(x: "x", y: "y"),
  layers: (
    geom-tile(
      data: d => d.filter(t => not t.doubtful),
      mapping: aes(fill: "paint", alpha: "strength"),
      width: tile-width,
      height: tile-height,
    ),
    geom-tile(
      data: d => d.filter(t => t.doubtful),
      mapping: aes(colour: "paint", alpha: "strength"),
      width: tile-width - 0.08,
      height: tile-height - 0.08,
      fill: parchment,
      stroke: 0.6pt,
    ),
    geom-typst(
      data: name-rows,
      mapping: aes(label: "content"),
      anchor: "east",
    ),
    geom-typst(
      data: count-rows,
      mapping: aes(label: "content"),
      anchor: "west",
    ),
  ),
  scales: scales(
    x: scale-continuous(limits: (-4.2, calc.max(..works.map(w => w.sure + w.doubtful)) + 3.6), expand: (0%, 0%)),
    y: scale-continuous(limits: (0.4, works.len() + 0.6), expand: (0%, 0%)),
    fill: scale-identity(),
    colour: scale-identity(),
    alpha: scale-identity(),
  ),
  guides: guides(default: none),
  labels: labels(
    title: "Jubilees Kept Pace With Exodus",
    subtitle: [
      Each tile is one manuscript found near the Dead Sea, and each row a work with at least #min-copies certain copies. #as-ink([Scripture], ink) is in ink, #as-ink([works outside the Hebrew Bible], rubric) in red. \
      Jubilees, a retelling of Genesis and Exodus that never entered the canon, survives in #work-at("Jubilees").sure certain copies. So does Exodus.
    ],
    caption: [
      Copies on papyrus, in the old Hebrew script, or in Greek count towards their work. Outlined tiles are copies the editors mark as uncertain, and the counts on the right leave them out. \
      Phylacteries, mezuzot, and fragments not tied to one work are not drawn. \
      Source: Leon Levy Dead Sea Scrolls Digital Library (TidyTuesday 2026-09-15). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: none,
  ),
  theme: theme-void(
    ink: ink,
    plot-title: element-text(font: "Frank Ruhl Libre", size: 16pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: body-font, size: 8pt, colour: ink),
    plot-caption: element-text(font: body-font, size: 6pt, colour: ink.transparentize(20%)),
    plot-background: element-rect(fill: parchment, colour: none),
  ),
  width: auto,
  height: auto,
)
