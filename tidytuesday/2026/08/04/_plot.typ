// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// importing it again here is redundant.
// #import "@preview/gribouille:0.6.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per month per importing country: how many kilos of Lesotho wool
// (HS 5101) landed there, and what they were worth. These are mirror
// statistics, so Lesotho's exports are read off the countries that bought
// them. Every number in the chart is derived from this table.
// Source: data/basotho_wool.csv (TidyTuesday 2026-08-04).
#let raw = csv("data/basotho_wool.csv", row-type: dictionary)

#let comma = format-comma()
#let pct = format-percent()
#let dp2 = format-number(digits: 2)

#let month-names = (
  "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.",
  "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec.",
)

// The clip is sheared in the southern spring, so a calendar year cuts one
// season in half. Months are placed on a shearing year running September to
// August: September is 1, December is 4, April is 8. Nothing in the data
// reaches past 9, so the axis never has to wrap.
#let shear-pos(m) = calc.rem(m - 9 + 12, 12) + 1

// `qty` is zero on twenty-five of the twenty-eight India rows and missing on
// one more, so weight comes from `net_wgt`, which is present and non-zero on
// every row.
#let tonnes-of(r) = float(r.net_wgt) / 1000

// Where a year's kilos sit on the calendar, as a vector mean over the twelve
// months weighted by weight. A mean is the right summary here only because the
// concentration `R` stays high enough to make it one; the caption reports how
// low it gets.
#let mean-month(weights) = {
  let total = weights.sum()
  let s = 0.0
  let c = 0.0
  for (i, w) in weights.enumerate() {
    let a = 2 * calc.pi * i / 12
    s += w * calc.sin(a)
    c += w * calc.cos(a)
  }
  let ang = calc.atan2(c, s).rad()
  if ang < 0 { ang += 2 * calc.pi }
  (
    month: ang / (2 * calc.pi) * 12 + 1,
    concentration: calc.sqrt(s * s + c * c) / total,
  )
}

// One pass over the 293 rows: each year's monthly weights, and how much of the
// year went to China rather than to the South African auction floor.
#let tally = (:)
#for r in raw {
  let key = r.ref_year
  let acc = tally.at(key, default: (months: (0.0,) * 12, china: 0.0))
  let t = tonnes-of(r)
  acc.months.at(int(r.ref_month) - 1) += t
  if r.reporter_iso == "CHN" { acc.china += t }
  tally.insert(key, acc)
}

#let years = tally.pairs().map(((key, acc)) => {
  let total = acc.months.sum()
  let m = mean-month(acc.months)
  (
    year: int(key),
    label: key,
    arrival: shear-pos(m.month),
    concentration: m.concentration,
    share: 100 * acc.china / total,
    tonnes: total,
  )
}).sorted(key: y => y.year)

// Two counts are spelled out in prose rather than computed into it, so a
// sixteenth year or a seventh China-free year fails loudly instead of quietly
// contradicting the words.
#assert(years.len() == 15, message: "the data no longer covers fifteen years")
#assert(
  years.filter(y => y.share == 0).len() == 6,
  message: "the run of years with no wool going to China is no longer six long",
)

#let first-year = years.first()
#let peak = years.sorted(key: y => y.share).last()
#let latest = years.sorted(key: y => y.arrival).last()
#let flattest = years.sorted(key: y => y.concentration).first()
#let total-tonnes = years.map(y => y.tonnes).sum()

// The share peak and the volume trough are the same two years, which is the one
// thing circle area is in the figure to say: 2018 sent 78% of the clip east, but
// of the smallest clip of any year after 2011. Read without the weights, the
// peak of the excursion looks like the moment the most wool went east, when it
// is nearer the opposite.
#let heaviest = years.sorted(key: y => y.tonnes).last()
// Guards the sentence on the page that calls 2018 and 2019 the two lightest
// years after 2011.
#assert(
  years
    .filter(y => y.year > 2011)
    .sorted(key: y => y.tonnes)
    .slice(0, 2)
    .map(y => y.label) == ("2018", "2019"),
  message: "2018 and 2019 are no longer the two lightest years after 2011",
)

// The path itself: one hop per pair of consecutive years, drawn as a bowed
// segment so the excursion reads as a journey out and back rather than as a
// zigzag. The bow is shallow; at 0.5 the return leg crosses the outbound one.
// Each hop carries the year it leaves, so the thread can be shaded along its
// length and the reader can tell which way round the excursion runs without
// reading every label.
#let hops = ()
#for i in range(years.len() - 1) {
  let a = years.at(i)
  let b = years.at(i + 1)
  hops.push((x: a.arrival, y: a.share, xend: b.arrival, yend: b.share, from: a.year))
}

// Weight twice over: as circle area, and as one of four fill bins. The two
// channels agree, so the smallest circles are also the palest, and on a white
// page a pale fill on a small mark is the one thing that disappears. The
// constant ring is what stops it: every circle keeps the same outline whatever
// its bin, so the mark holds its edge on the pale page and the dark one alike
// and the fill is left to carry the bin alone.
#let circle-fill = rgb("#4a90bd")

// Four bins rather than a ramp, so weight is read off a key instead of guessed
// from a gradient. The edges are round numbers covering 885 to 9,626 tonnes,
// and they split the fifteen years 3 / 2 / 5 / 5.
//
// The bin is cut here and mapped as a discrete scale rather than left to
// `scale-steps`, because a binned continuous scale still draws its guide as one
// colourbar; four named swatches are what a reader can actually match a circle
// against.
#let tonne-edges = (2500, 5000, 7500)
#let tonne-labels = ("Under 2,500", "2,500 to 5,000", "5,000 to 7,500", "Over 7,500")
// Four steps, all of them lighter than the dark theme's page. Running the ramp
// down into a deep blue separates the bins nicely on white but collapses the
// top two against a near-black background, where a dark swatch has nowhere left
// to go. Keeping every step above the dark page costs contrast at the pale end
// on white, which is exactly what the constant ring is there to cover.
#let tonne-colours = (
  rgb("#dceaf4"),
  rgb("#a3c9e2"),
  rgb("#6aa4c9"),
  rgb("#2f7fc4"),
)
#let bin-of(t) = tonne-labels.at(tonne-edges.filter(e => t >= e).len())
#let binned-bins = years.map(y => y + (bin: bin-of(y.tonnes)))

// Label offsets in canvas centimetres, set by hand. Fifteen labels is few
// enough to place deliberately, and every rule tried here walked them outward
// until they stopped colliding, which produced long queues no reader benefits
// from and cost the panel real height to fit.
//
// Positive x is right, positive y is up. A label is centred on its offset, so a
// sideways one needs about 0.28cm more than an upright one to clear its own
// circle.
#let label-nudges = (
  "2010": (0.00, -0.25),
  "2011": (0, 0.35),
  "2012": (0.25, -0.4),
  "2013": (0.55, 0.2),
  "2014": (-0.25, -0.4),
  "2015": (-0.35, 0.35),
  "2016": (0, 0.4),
  "2017": (0, 0.45),
  "2018": (0, 0.32),
  "2019": (0.40, 0.32),
  "2020": (0.6, 0.1),
  "2021": (0, -0.45),
  "2022": (-0.5, 0.25),
  "2023": (0, -0.45),
  "2024": (0.6, 0),
)

// Strict on purpose: a year missing from the table fails the render rather than
// quietly defaulting to zero and printing its label on top of its own circle.
#let binned = binned-bins.map(y => {
  let (dx, dy) = label-nudges.at(y.label)
  y + (nudge-x: dx * 1cm, nudge-y: dy * 1cm)
})

// The thread is shaded along its length so the excursion reads as a direction
// rather than a loop of unknown handedness. The ramp gains saturation without
// changing lightness much: 2010 leaves as a neutral grey, 2024 arrives as full
// blue. That is the one kind of ramp this figure can carry, since a
// pale-to-dark ramp has to fail against either the white page or the near-black
// one at whichever end sits closest to it.
#let hop-early = rgb("#b6bac1")
#let hop-late = rgb("#15618f")
#let ink-soft = rgb("#7d838c")

// The page colour the theme resolved from the typst-render inputs, so the key
// can sit on the panel without the grid showing through it and still follow the
// site's light and dark toggle.
#let paper-colour = theme-minimal().at("paper", default: white)

#let body-font = "Lato"
#let chart-font = "Archivo"

#plot(
  data: binned,
  mapping: aes(x: "arrival", y: "share"),
  layers: (
    // Behind the points: the chronological thread.
    geom-curve(
      data: hops,
      mapping: aes(x: "x", y: "y", xend: "xend", yend: "yend", colour: "from"),
      inherit-aes: false,
      curvature: 0.22,
      stroke: 1.1pt,
    ),
    // The ring is the accent colour rather than white: white separates
    // overlapping circles on the pale page but cuts a bright gap out of them on
    // the dark one.
    geom-point(
      mapping: aes(size: "tonnes", fill: "bin"),
      colour: circle-fill,
      alpha: 0.85,
      stroke: 0.5pt,
    ),
    // Each label is offset by the hand-set pair joined on above, so where a
    // label sits is a decision recorded in `label-nudges` rather than the
    // output of a layout pass.
    geom-text(
      mapping: aes(label: "label", nudge-x: "nudge-x", nudge-y: "nudge-y"),
      anchor: "center",
      size: 6.5pt,
      font: body-font,
      colour: ink-soft,
    ),
  ),
  scales: scales(
    x: scale-continuous(
      breaks: range(3, 9),
      labels: range(3, 9).map(p => month-names.at(calc.rem(p + 7, 12))),
    ),
    y: scale-continuous(
      breaks: (0, 20, 40, 60, 80),
      labels: v => str(v) + "%",
      expand: (18%, 10%),
    ),
    size: scale-area(range: (2.5pt, 9pt)),
    colour: scale-gradient(low: hop-early, high: hop-late),
    fill: scale-discrete(
      limits: tonne-labels,
      palette: tonne-colours,
    ),
  ),
  // Size and fill say the same thing, so only one key is drawn. It sits inside
  // the panel, in the bottom right, which is the one corner of this figure that
  // no circle and no thread reaches; outside the panel it would cost the
  // caption a line it cannot spare at 9.45 cm.
  // The thread's own ramp gets no key either: it repeats what the fifteen year
  // labels already say, and a second guide inside the panel would cost more
  // room than the direction cue is worth.
  guides: guides(
    size: none,
    colour: none,
    fill: guide-legend(position: bottom + right, key-size: 0.32cm),
  ),
  labels: labels(
    title: "Lesotho's Wool Left in November and Came Back in April",
    subtitle: [
      One circle per year, sized and shaded by the year's tonnage and placed by the month Lesotho's kilos landed and by how
      much of the clip went east rather than to the South African auction floor. The thread joins the years in order:
      out to #latest.label, when the average consignment did not land until #month-names.at(calc.rem(int(latest.arrival) + 7, 12)), #calc.round(latest.arrival - first-year.arrival, digits: 1) months later in the year than in #first-year.label, and back again.
      Watch the circles shrink as it goes: #peak.label sent #pct(peak.share / 100) east, but of #comma(calc.round(peak.tonnes)) tonnes against #comma(calc.round(heaviest.tonnes)) in #heaviest.label.
    ],
    x: "Average month the year's wool arrives",
    y: "Share of the year's kilos landing in China",
    fill: "Tonnes in the year",
    // Each line has to fit on one rendered line at 6.5 pt across 18 cm, so
    // roughly 150 characters; a wrapped caption runs off the bottom of the page.
    caption: typst([
      #comma(calc.round(total-tonnes)) tonnes over #raw.len() monthly records, #comma(calc.round(first-year.tonnes)) to #comma(calc.round(years.sorted(key: y => y.tonnes).last().tonnes)) a year. A year's month is a weight-weighted vector mean; concentration runs #dp2(flattest.concentration) to #dp2(years.sorted(key: y => y.concentration).last().concentration). \
      India and Uruguay take 1.3% of the kilos and are not drawn; twenty China records are flagged as estimated. \
      Lesotho's 2018 wool and mohair regulations routed the clip through a broker at home. Source: UN Comtrade (TidyTuesday 2026-08-04). Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
  ),
  theme: theme-minimal(
    legend-background: element-rect(fill: paper-colour),
    plot-title: element-text(font: chart-font, size: 17pt, weight: "bold"),
    plot-subtitle: element-text(font: body-font, size: 8.5pt),
    plot-caption: element-text(font: body-font, size: 6.5pt),
    axis-title: element-text(font: body-font, size: 8pt),
    axis-text: element-text(font: body-font, size: 7pt),
    legend-title: element-text(font: body-font, size: 7.5pt, weight: "bold"),
    legend-text: element-text(font: body-font, size: 7pt),
    axis-ticks: element-tick(length: 0.05cm),
  ),
  width: auto,
  height: auto,
)
