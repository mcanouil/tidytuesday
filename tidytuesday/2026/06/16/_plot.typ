// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@local/gribouille:0.0.0": *
// #import "@preview/gribouille:0.4.1": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Treat every missing sentinel as `none` so a single guard filters them out.
#let num(s) = if s in ("NA", "N/A", "") { none } else { float(s) }

#let files = (
  ("England & Wales", "data/england_wales_names.csv"),
  ("Scotland", "data/scotland_names.csv"),
  ("Northern Ireland", "data/ni_names.csv"),
)

// Keep only years where all three nations publish data (E&W ends at 2024).
#let start_year = 1997
#let end_year = 2024
// A name counts as gender-neutral when the combined UK total for each sex
// reaches at least this many births; filters ONS-suppressed entries and noise.
#let min_n = 3

// Pass 1: sum births across nations per (year, name, sex) for shared years only.
#let year_name_sex = (:)
#for (_, path) in files {
  for r in csv(path, row-type: dictionary) {
    let yr = int(r.Year)
    if yr < start_year or yr > end_year { continue }
    let n = num(r.Number)
    if n == none { continue }
    let key = r.Year + "|" + r.Name + "|" + r.Sex
    year_name_sex.insert(key, year_name_sex.at(key, default: 0.0) + n)
  }
}

// Pass 2: apply threshold after combining; index which names qualify per sex.
#let year_name = (:)
#for (key, total_n) in year_name_sex {
  if total_n < min_n { continue }
  let parts = key.split("|")
  let name_key = parts.at(0) + "|" + parts.at(1)
  let sex = parts.at(2)
  let cur = year_name.at(name_key, default: (:))
  cur.insert(sex, true)
  year_name.insert(name_key, cur)
}

// Pass 3: count shared and total distinct names per year.
#let per_year = (:)
#for (key, counts) in year_name {
  let yr = key.split("|").at(0)
  let cur = per_year.at(yr, default: (shared: 0, total: 0))
  cur.insert("total", cur.total + 1)
  if "Boy" in counts and "Girl" in counts {
    cur.insert("shared", cur.shared + 1)
  }
  per_year.insert(yr, cur)
}

// Mean total distinct names across all years (used in y-axis "% (N)" label).
#let total_sum = 0.0
#let n_yrs = 0
#for (_, v) in per_year {
  total_sum += v.total
  n_yrs += 1
}
#let mean_total = total_sum / n_yrs

// Pass 4: find top gender-neutral name (by combined births) per 5-year interval.
// Intervals are half-open [start, end); labels placed at midpoint year.
#let intervals = (
  (start: 1997, end: 2000, mid: 1998),
  (start: 2000, end: 2005, mid: 2002),
  (start: 2005, end: 2010, mid: 2007),
  (start: 2010, end: 2015, mid: 2012),
  (start: 2015, end: 2020, mid: 2017),
  (start: 2020, end: 2025, mid: 2022),
)

#let interval_totals = (:)
#for (key, total_n) in year_name_sex {
  let parts = key.split("|")
  let yr = int(parts.at(0))
  let name = parts.at(1)
  let name_key = parts.at(0) + "|" + name
  let sexes = year_name.at(name_key, default: (:))
  if "Boy" not in sexes or "Girl" not in sexes { continue }
  for (i, iv) in intervals.enumerate() {
    if yr >= iv.start and yr < iv.end {
      let k = str(i) + "|" + name
      interval_totals.insert(k, interval_totals.at(k, default: 0.0) + total_n)
    }
  }
}

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

// Build one row per year, sorted chronologically.
#let rows = ()
#let max_pct = 0.0
#for (yr, v) in per_year {
  let pct = v.shared / v.total * 100
  if pct > max_pct { max_pct = pct }
  rows.push((year: int(yr), pct: pct))
}
#let rows = rows.sorted(key: r => r.year)

// Okabe-Ito teal for the single series.
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
  scales: (
    scale-x-continuous(breaks: (2000, 2005, 2010, 2015, 2020)),
    scale-y-continuous(
      name: "Share of All Distinct Names",
      limits: (0, max_pct + 0.5),
      // Labels show percentage and approximate count in parentheses.
      labels: p => {
        let n = int(calc.round(p / 100 * mean_total))
        str(calc.round(p, digits: 1)) + "% (" + str(n) + ")"
      },
    )
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
