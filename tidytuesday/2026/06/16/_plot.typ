// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.2.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Treat every missing sentinel as `none` so a single guard filters them out.
#let num(s) = if s in ("NA", "N/A", "") { none } else { float(s) }

// Okabe-Ito accents (colourblind-safe): teal for boys, orange for girls.
#let boy = rgb("#009e73")
#let girl = rgb("#e69f00")

// Each nation publishes to a different depth, so the share is computed within a
// nation (consistent over its own years); the falling TREND is the comparison,
// not the absolute level across nations.
#let files = (
  ("England & Wales", "data/england_wales_names.csv"),
  ("Scotland", "data/scotland_names.csv"),
  ("Northern Ireland", "data/ni_names.csv"),
)

#let topn = 10

// Long table: one row per (nation, sex, year) carrying the top-10 names' share
// of recorded births. Built with a for-loop (Gribouille tables don't survive a
// flatten of nested arrays).
#let rows = ()
#for (nation, path) in files {
  let agg = (:)
  for r in csv(path, row-type: dictionary) {
    let n = num(r.Number)
    if n == none { continue }
    let key = r.Sex + "|" + r.Year
    let cur = agg.at(key, default: (total: 0.0, top: 0.0))
    cur.total += n
    let rk = num(r.Rank)
    if rk != none and rk <= topn { cur.top += n }
    agg.insert(key, cur)
  }
  for (key, v) in agg {
    let parts = key.split("|")
    rows.push((
      nation: nation,
      sex: parts.at(0),
      year: int(parts.at(1)),
      share: v.top / v.total,
    ))
  }
}

#plot(
  data: rows,
  mapping: aes(x: "year", y: "share", colour: "sex"),
  layers: (
    geom-line(),
    geom-point(size: 1.4pt),
  ),
  facet: facet-wrap("nation", ncolumn: 3),
  scales: (
    scale-x-continuous(breaks: (1980, 2000, 2020)),
    scale-y-continuous(
      name: "Top-10 Names' Share of Recorded Births",
      limits: (0, 0.4),
      labels: format-percent(),
    ),
    scale-colour-manual(values: (boy, girl), limits: ("Boy", "Girl")),
  ),
  guides: guides(colour: none),
  labs: labs(
    title: "Britain's Top Baby Names Are Losing Their Grip",
    subtitle: [
      Across all three nations the #strong[ten most popular names]' share of
      recorded births has roughly halved since the 1990s, for both
      #text(fill: boy, weight: "bold")[boys] and
      #text(fill: girl, weight: "bold")[girls]. \
      Parents are spreading their choices across an ever wider pool.
    ],
    caption: [
      Source: UK baby names (TidyTuesday 2026-06-16). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none
  ),
  theme: theme-minimal(plot-subtitle: element-typst(size: 8.5pt)),
  width: auto,
  height: auto,
)
