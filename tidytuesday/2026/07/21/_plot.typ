// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.4.1": *
#import "@local/gribouille:0.0.0": *
#set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per account submitted to the near-death experience archive. Both the
// Greyson score and the eight theme flags are derived from the narrative text
// rather than from an interview, which is the caveat the caption carries.
// Every number in the chart is computed from this table, so the figure is
// reproducible end to end: no hand-typed counts and no pre-summarised file.
// Source: data/nde_experiences.csv (TidyTuesday 2026-07-21).
#let raw = csv("data/nde_experiences.csv", row-type: dictionary)

// Scores are written as whole numbers, with "NA" where none was assigned.
#let score-of(v) = if v == none or v == "" or v == "NA" { none } else { int(v) }
#let pct = format-percent()

// The Greyson NDE Scale runs 0 to 32 and treats 7 as the threshold at which an
// account counts as a near-death experience. That single number is what the
// chart is built around.
#let threshold = 7
#let scale-max = 32

// The eight themes the archive codes for, each with the plain-English gloss the
// axis carries beside its column name. Order here is only the source order; the
// rows are sorted by how many accounts carry each theme.
#let theme-specs = (
  (col: "ai_clinical", gloss: "clinical crisis"),
  (col: "ai_obe", gloss: "out-of-body"),
  (col: "ai_unity", gloss: "oneness, unity"),
  (col: "ai_esp", gloss: "extrasensory perception"),
  (col: "ai_hellish", gloss: "distressing, hellish"),
  (col: "ai_world_future", gloss: "the world's future"),
  (col: "ai_past_lives", gloss: "past lives"),
  (col: "ai_aliens", gloss: "aliens"),
)

// Every account carrying a score, whatever its themes: the denominator behind
// the headline share.
#let scored = raw.map(r => score-of(r.greyson_score)).filter(s => s != none)
#let n-accounts = raw.len()
#let n-scored = scored.len()
#let n-above = scored.filter(s => s >= threshold).len()
#let pct-above = pct(n-above / n-scored)
#let overall-median = median(scored).y
#let archive-max = calc.max(..scored)

// One pass per theme, collecting the scores of every account that carries it.
// An account can carry several themes, so it appears in several rows; each row
// is that theme's own distribution, not a slice of a partition. Commonest theme
// first: the panel is built upright and then flipped, so slot 1 lands at the
// bottom and the slots count down.
#let rows = theme-specs.map(spec => {
  let s = raw
    .filter(r => r.at(spec.col) == "TRUE")
    .map(r => score-of(r.greyson_score))
    .filter(v => v != none)
  spec + (
    n: s.len(),
    median: median(s).y,
    above: s.filter(v => v >= threshold).len(),
    scores: s,
  )
}).sorted(key: t => t.n).rev()
#let n-rows = rows.len()
#let slot-of(i) = n-rows - i

// The row whose tail clears the threshold most often, found by share rather
// than by position, and the row too small to say anything about. Rows under
// twenty accounts are excluded from the first search, since a couple of
// accounts would otherwise decide it.
#let stretch = rows.filter(t => t.n >= 20).sorted(key: t => t.above / t.n).last()
#let stretch-pct = pct(stretch.above / stretch.n)
#let biggest = rows.first()
#let thinnest = rows.last()

// One long table, one point per account per theme it carries. The band is the
// only thing colour encodes: whether that account reaches the threshold.
#let bands = ("below", "at or above")
#let points = ()
#for (i, t) in rows.enumerate() {
  for s in t.scores {
    points.push((
      slot: slot-of(i),
      score: s,
      band: if s >= threshold { bands.last() } else { bands.first() },
    ))
  }
}

// The subtitle claims no theme shifts the middle of the distribution, so the
// figure fails loudly if a median ever crosses the threshold.
#let medians = rows.map(t => t.median)
#let median-lo = calc.min(..medians)
#let median-hi = calc.max(..medians)
#assert(
  median-hi < threshold,
  message: "a theme's median now reaches the threshold: " + repr(medians),
)

// The crimson is reserved for the accounts that clear the threshold; everything
// below it is a backdrop rather than a second category, so that neutral is meant
// to read as grey. The threshold rule and the per-row counts repeat the split,
// so identity never rests on colour. Both clear the colour-vision and contrast
// checks on the pale page and the dark one alike, so there is no light/dark
// branch here.
#let above-col = rgb("#c93b4c") // crimson: reaches the diagnostic threshold
#let below-col = rgb("#9a8f80") // warm neutral: the rest of the archive
#let rule-col = rgb("#8a8f96") // the row medians, a mark rather than a category

// A plain public-record sans for the prose, and a data face for the column
// names, because the row labels are literally columns of the dataset. Both are
// vendored in assets/fonts, so CI renders them too.
#let body-font = "Public Sans"
#let mono-font = "IBM Plex Mono"

// No fill means "say nothing about the colour", so the text inherits the page
// ink and stays legible whichever way the site is toggled. A colour is passed
// only for text naming a coloured mark; secondary text steps down in size.
#let note(body, fill: none, size: 7pt, weight: "regular") = {
  set text(fill: fill) if fill != none
  text(font: body-font, size: size, weight: weight)[#body]
}
#let col-name(name, size: 8pt) = text(
  font: mono-font, size: size, weight: "medium",
)[#name]

// Two-line tick label: the column name as it appears in the data, then the
// gloss, how many accounts carry the theme, and how many of those reach the
// threshold. Those counts do the work a legend would otherwise do.
#let row-label(t) = box(inset: (right: 3pt))[
  #set align(right)
  #set par(leading: 2pt)
  #col-name(t.col, size: 7.5pt) \
  #note(size: 6pt)[#t.gloss · n #t.n, #t.above at #sym.gt.eq #threshold]
]

// Each row's median, as a rule across its own swarm. Sized in data units off
// the same width as the swarm, so it tracks the rows rather than a fixed
// height in points.
#let swarm-width = 0.32
#let median-marks = rows.enumerate().map(((i, t)) => (
  slot: slot-of(i), median: t.median,
))

#plot(
  data: points,
  mapping: aes(x: "slot", y: "score", fill: "band", alpha: "band"),
  layers: (
    // The threshold itself: the line almost nothing crosses. Drawn half a point
    // below 7, so it separates the integer scores rather than covering one.
    geom-hline(
      yintercept: threshold - 0.5,
      stroke: 0.9pt, colour: above-col, linetype: "dashed", inherit-aes: false,
    ),
    // One dot per account, swarmed so the thickness of a row shows where its
    // scores pile up. Small and translucent, because the dense rows carry
    // hundreds of accounts on top of each other.
    geom-beeswarm(
      size: 1.6pt, stroke: 0pt,
      position: position-beeswarm(width: swarm-width),
    ),
    // Each row's own median, all eight of them stacked in the same narrow band.
    geom-errorbarh(
      data: median-marks,
      mapping: aes(x: "slot", xmin: "median", xmax: "median"),
      inherit-aes: false, height: swarm-width, stroke: 2pt, colour: rule-col,
    ),
    // Both rules are labelled in the empty band above the top row, so the panel
    // reads without a legend.
    annotate(
      "typst", x: n-rows + 0.5, y: threshold - 0.5,
      label: note(fill: above-col, size: 7.5pt, weight: "bold")[Threshold #threshold],
      anchor: "south-west", clip: false,
    ),
    annotate(
      "typst", x: n-rows + 0.5, y: overall-median,
      label: note(size: 7.5pt)[row medians, #median-lo to #median-hi],
      anchor: "south-east", clip: false,
    ),
    // One callout out in the long empty tail, where the scores the scale was
    // built for would sit if the archive ever reached them.
    annotate(
      "typst", x: n-rows - 0, y: 11,
      label: box(width: 8.4cm)[
        #note(fill: above-col, size: 9pt, weight: "bold")[
          #n-above of #n-scored scored accounts (#pct-above) reach #threshold.
        ] \
        #note(size: 7.5pt)[
          The scale runs to #scale-max, and the whole archive stops at
          #archive-max.
        ]
      ],
      anchor: "north-west", clip: false,
    ),
  ),
  scales: scales(
    x: scale-continuous(
      breaks: range(n-rows).map(slot-of),
      labels: rows.map(row-label),
      limits: (0.4, n-rows + 0.85),
      expand: (0%, 0%),
    ),
    y: scale-continuous(
      breaks: (0, 5, 10, 15, 20, 25, 30),
      limits: (-0.8, scale-max),
      expand: (0%, 1%),
    ),
    fill: scale-manual(values: (below-col, above-col), limits: bands),
    // The handful of accounts that clear the threshold are the point of the
    // figure, so they run at full strength while the bulk below it recedes.
    alpha: scale-manual(values: (0.6, 1), limits: bands),
  ),
  coord: coord-flip(),
  guides: guides(default: none),
  labels: labels(
    title: "Almost No Account Reaches the Greyson Threshold",
    // Under coord-flip the scale keys stay pre-flip, so `x` is the row axis on
    // the left and `y` is the score axis along the bottom.
    x: none,
    y: "Greyson NDE Scale Score",
    subtitle: [
      The Greyson NDE Scale counts an account as a near-death experience at
      #text(fill: above-col, weight: "bold")[#threshold points] out of #scale-max. \
      Across #n-scored scored accounts, all
      but #text(fill: above-col, weight: "bold")[#n-above of them] fall
      #text(fill: below-col.darken(15%), weight: "bold")[below that line], and
      no theme shifts the middle: every row's median sits between
      #median-lo and #median-hi. 
      Even #col-name(stretch.col, size: 8.5pt), whose
      tail clears the threshold most often, does so in only #stretch-pct of the
      accounts that carry it.
    ],
    caption: typst([
      #n-accounts accounts, #n-scored of them scored; one dot per account per theme, so an account carrying several themes appears in several rows and the rows are not a partition. \
      Score and themes are both derived from the narrative text, not from an interview. Rows run from #biggest.n accounts down to #thinnest.n, and #col-name(thinnest.col, size: 6.5pt) supports no inference. \
      Source: near-death experience archive (TidyTuesday 2026-07-21). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    plot-title: element-text(font: body-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8.5pt),
    axis-text-y: element-text(font: mono-font, size: 7.5pt),
    panel-grid-major-x: element-blank(),
    panel-grid-minor: element-blank(),
  ),
  width: auto,
  height: auto,
)
