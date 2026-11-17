// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// Group a whole number with thousands separators, e.g. 8258 -> "8,258".
#let thousands = format-comma(digits: 0)
#let pct(part, whole) = format-percent()(part / whole)

// Every number below comes from the raw fight table.
// Source: data/ufc_fights.csv, one row per UFC bout (UFCStats via {fightr}).
// One pass over the raw fights, counting knockouts, submissions and decisions per
// gender and division. A weight class with no fixed limit has no position on the
// weight axis, so it is excluded.
#let fights = {
  csv("data/ufc_fights.csv", row-type: dictionary)
    .filter(r => not ("Open Weight", "Catch Weight", "Tournament").any(w => r.weight_class.contains(w)))
    .map(r => (
      gender: if r.weight_class.contains("Women's") { "Women" } else { "Men" },
      // Canonical division names, longest first, so "Light Heavyweight" matches
      // before "Heavyweight" when scanned inside the raw "weight_class". That
      // column carries prefixes and suffixes such as "UFC ... Title" and " Bout".
      division: (
        "Light Heavyweight", "Heavyweight", "Middleweight", "Welterweight",
        "Lightweight", "Featherweight", "Bantamweight", "Flyweight", "Strawweight",
      ).find(n => r.weight_class.contains(n)),
      // Collapse the raw "method" strings into the three finish types the chart
      // shows. A disqualification, an overturned result or a stoppage is not a
      // finish, so it is dropped.
      finish: if r.method.starts-with("KO/TKO") { "ko" } else if r.method.starts-with("Submission") {
        "sub"
      } else if r.method.starts-with("Decision") { "dec" } else { none },
    ))
    .filter(r => r.division != none and r.finish != none)
}


// The divisions to draw, lightest to heaviest within each gender, each with its
// weight limit in pounds. The order is stated once here.
#let spec = (
  (gender: "Men", class: "Flyweight", lb: 125),
  (gender: "Men", class: "Bantamweight", lb: 135),
  (gender: "Men", class: "Featherweight", lb: 145),
  (gender: "Men", class: "Lightweight", lb: 155),
  (gender: "Men", class: "Welterweight", lb: 170),
  (gender: "Men", class: "Middleweight", lb: 185),
  (gender: "Men", class: "Light Heavyweight", lb: 205),
  (gender: "Men", class: "Heavyweight", lb: 265),
  (gender: "Women", class: "Strawweight", lb: 115),
  (gender: "Women", class: "Flyweight", lb: 125),
  (gender: "Women", class: "Bantamweight", lb: 135),
  (gender: "Women", class: "Featherweight", lb: 145),
)

#let key(gender, division) = gender + "|" + division
#let totals = {
  let t = (:)
  for r in count(fights, "gender", "division") { t.insert(key(r.gender, r.division), r.n) }
  t
}
#let finish-names = (ko: "KO/TKO", sub: "Submission", dec: "Decision")
#let finish-limits = ("KO/TKO", "Submission", "Decision")

// One row per division and finish, straight from the tally of raw fights.
// `rank` fixes the stacking order: the stack puts the first level of `group` at
// the top of the bar, which is the right end once the axes flip, so the
// knockout (rank 3) sits at the left edge. The submission share carries no
// label.
#let bars = (
  count(fights, "gender", "division", "finish")
    .filter(t => spec.any(s => key(s.gender, s.class) == key(t.gender, t.division)))
    .map(t => {
      let k = key(t.gender, t.division)
      let label = pct(t.n, totals.at(k))
      (
        key: k,
        cat: finish-names.at(t.finish),
        n: t.n,
        share: t.n / totals.at(k),
        rank: finish-limits.len() - finish-limits.position(c => c == finish-names.at(t.finish)),
        text: if t.finish == "sub" { "" } else { label },
      )
    })
)

#let n-total = spec.map(s => totals.at(key(s.gender, s.class))).sum()
#let share(gender, division, finish) = {
  let hit = bars.find(b => b.key == key(gender, division) and b.cat == finish-names.at(finish))
  hit.n / totals.at(key(gender, division))
}
#let m-light-ko = share("Men", "Flyweight", "ko")
#let m-heavy-ko = share("Men", "Heavyweight", "ko")

// One palette, one source of truth. Vermillion is the knockout, blue the
// submission, and a warm grey the fight that goes to the judges. The three stay
// distinct under every colour-vision deficiency.
#let ko-col = rgb("#d55e00") // KO/TKO: the finish that lands hardest
#let sub-col = rgb("#5f8aa8") // submission: the flat middle, muted so it recedes behind the hero
#let dec-col = rgb("#a9a198") // decision: no finish, left to the scorecards
#let body-font = "Fira Sans"
#let chart-font = "Oswald" // condensed scoreboard face

// Men on top, women below, lightest to heaviest in each group, so the knockout
// wedge widens downward. An empty level separates the two genders.
#let gap-key = "gap"
#let division-keys = (
  spec.filter(s => s.gender == "Men").map(s => key(s.gender, s.class))
    + (gap-key,)
    + spec.filter(s => s.gender == "Women").map(s => key(s.gender, s.class))
)
#let heavy-slot = division-keys.position(k => k == key("Men", "Heavyweight")) + 1

#plot(
  data: bars,
  mapping: aes(x: "key", y: "share", fill: "cat", group: "rank"),
  layers: (
    // Thin edge so segments split on light or dark paper.
    geom-col(position: "stack", width: 0.76, stroke: 0.4pt + rgb("#3333334d")),
    // A dashed line at the halfway mark, which only the men's heavyweight
    // knockout wedge passes. Dark neutral, so it holds across all three
    // segment colours.
    geom-hline(yintercept: 0.5, stroke: 0.8pt + rgb("#2b2b2bcc"), linetype: "dashed", inherit-aes: false),
    // The knockout share sits in warm off-white on the vermillion wedge, and the
    // decision share closes each bar in dark ink on the quiet grey. The
    // submission share carries no label. One layer stacks them like the bars.
    geom-text(
      mapping: aes(label: "text", colour: "cat", size: "cat"),
      position: position-stack(),
      anchor: "east",
      font: chart-font,
    ),
    // An accent ring traces the men's heavyweight knockout wedge, tying its
    // callout to the data without recolouring the segment. Burnt vermillion reads
    // on the pale and the dark paper.
    annotate(
      "rect",
      xmin: heavy-slot - 0.38, xmax: heavy-slot + 0.38, ymin: 0, ymax: m-heavy-ko,
      fill: none, stroke: 1.3pt + rgb("#7a3300"), clip: false,
    ),
    // One callout, in the gap row under the heavyweight bar, so it never lands on
    // the data. Vermillion reads on both surfaces.
    annotate(
      "typst",
      x: heavy-slot + 1, y: 0,
      label: box(width: 9cm)[#text(size: 7.5pt, fill: ko-col, font: body-font, weight: "bold")[Over half of men's heavyweight bouts (#pct(m-heavy-ko, 1)) end in a knockout.]],
      anchor: "west", clip: false,
    ),
  ),
  scales: scales(
    x: scale-discrete(
      limits: division-keys,
      // Two-line tick label: the division name over its gender and weight limit
      // (converted from pounds to whole kilograms), so the axis states the gender
      // and the ordering itself.
      labels: k => if k == gap-key { [] } else {
        let r = spec.find(s => key(s.gender, s.class) == k)
        box(inset: (right: 2pt))[
          #set align(right)
          #text(font: chart-font, size: 9pt, weight: "bold")[#upper(r.class)] #text(font: body-font, size: 6.5pt, fill: dec-col.darken(20%))[#r.gender · #r.lb lb (#calc.round(r.lb * 0.45359237) kg)]
        ]
      },
    ),
    y: scale-continuous(
      name: "Share of Fights, by How They Ended",
      breaks: (0, 0.25, 0.5, 0.75, 1),
      labels: ("0", "25", "50", "75", "100%"),
      expand: (0.5%, 2%),
    ),
    fill: scale-manual(values: (ko-col, sub-col, dec-col), limits: finish-limits),
    colour: scale-manual(values: (rgb("#faf6f0"), black, rgb("#3a352f")), limits: finish-limits),
    size: scale-manual(values: (9.5pt, 8pt, 8pt), limits: finish-limits),
  ),
  coord: coord-flip(),
  guides: guides(default: none),
  labels: labels(
    x: none,
    title: "The Heavier the Division, the More Fights End in a Knockout",
    subtitle: [
      Across #thousands(n-total) UFC bouts, the share ending in a
      #text(fill: ko-col, weight: "bold")[knockout] climbs with the weight limit in both men's and women's divisions,
      from #pct(m-light-ko, 1) of men's flyweight bouts to #pct(m-heavy-ko, 1) of heavyweight,
      while the #text(fill: dec-col.darken(25%), weight: "bold")[decision] share falls the same way.
      #text(fill: sub-col.darken(20%), weight: "bold")[Submissions] stay near one in five throughout.
    ],
    caption: typst([
      Men's and women's divisions, #thousands(n-total) fights (1997–2026); ordered by weight limit within gender. \
      Open-weight, catch-weight and tournament bouts, and non-finishes (draws, disqualifications, no-contests) excluded. \
      Source: {fightr} package, UFCStats (TidyTuesday 2026-07-07). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text: element-text(font: body-font, size: 7.5pt),
    panel-grid: element-blank(),
    axis-ticks: element-tick(length: 0.1cm),
  ),
  width: auto,
  height: auto,
)
