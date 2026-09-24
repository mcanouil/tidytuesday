// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// A name counts as gender-neutral when the UK total for each sex reaches this
// many births. The floor removes ONS-suppressed entries and noise.
#let min_n = 3

// Sum births across nations per (year, name), with one total per sex.
#let year_name = (:)
#for path in ("data/england_wales_names.csv", "data/scotland_names.csv", "data/ni_names.csv") {
  for r in csv(path, row-type: dictionary) {
    // Keep only years where all three nations publish data (E&W ends at 2024).
    if int(r.Year) < 1997 or int(r.Year) > 2024 { continue }
    if r.Number in ("NA", "N/A", "") { continue }
    let key = r.Year + "|" + r.Name
    let cur = year_name.at(key, default: (:))
    cur.insert(r.Sex, cur.at(r.Sex, default: 0.0) + float(r.Number))
    year_name.insert(key, cur)
  }
}

// The commonest gender-neutral name per 5-year interval, by combined births.
// Intervals are half-open, and labels sit at the midpoint year.
#let intervals = (
  (start: 1997, end: 2000, mid: 1998),
  (start: 2000, end: 2005, mid: 2002),
  (start: 2005, end: 2010, mid: 2007),
  (start: 2010, end: 2015, mid: 2012),
  (start: 2015, end: 2020, mid: 2017),
  (start: 2020, end: 2025, mid: 2022),
)

// Apply the threshold after combining nations, then count shared and total
// distinct names per year and sum the births of shared names per interval.
#let per_year = (:)
#let interval_totals = (:)
#for (key, sexes) in year_name {
  let boy = sexes.at("Boy", default: 0.0) >= min_n
  let girl = sexes.at("Girl", default: 0.0) >= min_n
  if not (boy or girl) { continue }
  let (yr, name) = key.split("|")
  let cur = per_year.at(yr, default: (shared: 0, total: 0))
  cur.insert("total", cur.total + 1)
  if boy and girl {
    cur.insert("shared", cur.shared + 1)
    let i = intervals.position(iv => int(yr) >= iv.start and int(yr) < iv.end)
    let k = str(i) + "|" + name
    interval_totals.insert(k, interval_totals.at(k, default: 0.0) + sexes.values().sum())
  }
  per_year.insert(yr, cur)
}

// Mean total distinct names across all years (used in y-axis "% (N)" label).
#let mean_total = mean(per_year.values().map(v => v.total)).y

#let label_rows = ()
#for (i, iv) in intervals.enumerate() {
  let best_name = none
  let best_n = 0.0
  for (k, n) in interval_totals {
    if not k.starts-with(str(i) + "|") { continue }
    if n > best_n {
      best_n = n
      best_name = k.slice(str(i).len() + 1)
    }
  }
  if best_name == none { continue }
  let yr_data = per_year.at(str(iv.mid), default: (shared: 0, total: 1))
  let pct = yr_data.shared / yr_data.total * 100
  label_rows.push((year: iv.mid + 0.5, pct: pct, label: best_name))
}

#let rows = {
  per_year
    .pairs()
    .map(((yr, v)) => (year: int(yr), pct: v.shared / v.total * 100))
    .sorted(key: r => r.year)
}
#let max_pct = calc.max(..rows.map(r => r.pct))

#let teal = rgb("#009e73")

#plot(
  data: rows,
  mapping: aes(x: "year", y: "pct"),
  layers: (
    geom-area(fill: teal, alpha: 0.25, stroke: none, position: "identity"),
    geom-line(colour: teal, stroke: 0.8pt),
    geom-label(
      data: label_rows,
      mapping: aes(label: "label", nudge-y: 0.7cm),
      size: 7pt,
      fill: teal,
      colour: white,
      stroke: 0.3pt,
      inset: 3pt,
      radius: 1pt,
    ),
  ),
  scales: scales(
    x: scale-continuous(breaks: (2000, 2005, 2010, 2015, 2020), expand: (0%, 0%)),
    y: scale-continuous(
      name: "Share of All Distinct Names",
      limits: (0, max_pct + 0.5),
      // Each label carries the percentage and the count.
      labels: p => {
        let n = int(calc.round(p / 100 * mean_total))
        str(calc.round(p, digits: 1)) + "% (" + str(n) + ")"
      },
    ),
  ),
  labels: labels(
    title: "Britain's Gender-Neutral Baby Names",
    subtitle: [
      Names registered for both #strong[boys] and #strong[girls] across
      #text(fill: teal)[#strong[all three UK nations combined]] (_at least 3 births each sex, 1997–2024_). \
      Most-registered gender-neutral name labelled per five-year window.
    ],
    caption: [
      Source: UK baby names (TidyTuesday 2026-06-16). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
  ),
  theme: theme-minimal(),
  width: auto,
  height: auto,
)
