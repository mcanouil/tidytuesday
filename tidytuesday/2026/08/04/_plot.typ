// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// One row per month per importing country: kilos of Lesotho wool (HS 5101) and
// what they were worth. These are mirror statistics, so the exports are read off
// the countries that bought them.
// Source: data/basotho_wool.csv (TidyTuesday 2026-08-04).
#let raw = csv("data/basotho_wool.csv", row-type: dictionary)

#let comma = format-comma()
#let pct = format-percent()
#let dp2 = format-number(digits: 2)

#let month-names = (
  "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.",
  "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec.",
)

// The clip is sheared in the southern spring, so a calendar year splits one
// season. Months run September to August: September is 1, April is 8. Nothing
// reaches past 9, so the axis never wraps.
#let shear-pos(m) = calc.rem(m - 9 + 12, 12) + 1

// `qty` is zero on twenty-five of the twenty-eight India rows and missing on one
// more, so weight comes from `net_wgt`, which is present on every row.
#let tonnes-of(r) = float(r.net_wgt) / 1000

// Where a year's kilos sit on the calendar: a vector mean over the twelve months,
// weighted by weight. The mean holds only while the concentration `R` stays
// high, and the caption reports how low it gets.
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

// One pass over the 293 rows: monthly weights per year, and the share that went
// to China rather than to the South African auction floor.
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

// Two counts are spelled out in prose, so a sixteenth year or a seventh
// China-free year fails the render instead of contradicting the words.
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

// The share peak and the volume trough fall in the same two years, which is what
// circle area is here to say: 2018 sent 78% east, out of the smallest clip of
// any year after 2011. Without the weights, the peak reads as the opposite.
#let heaviest = years.sorted(key: y => y.tonnes).last()
// Guards the sentence on the page about the two lightest years after 2011.
#assert(
  years
    .filter(y => y.year > 2011)
    .sorted(key: y => y.tonnes)
    .slice(0, 2)
    .map(y => y.label) == ("2018", "2019"),
  message: "2018 and 2019 are no longer the two lightest years after 2011",
)

// The path: one hop per pair of consecutive years, bowed so the excursion reads
// as a journey out and back. At 0.5 the return leg would cross the outbound one.
// Each hop carries the year it leaves, so the thread can be shaded.
#let hops = ()
#for i in range(years.len() - 1) {
  let a = years.at(i)
  let b = years.at(i + 1)
  hops.push((x: a.arrival, y: a.share, xend: b.arrival, yend: b.share, from: a.year))
}

// Weight twice over: circle area, and one of four fill bins. The smallest circles
// are also the palest, and a pale fill on a small mark disappears. The ring is
// what stops it: every circle keeps the same outline whatever its bin.
#let circle-fill = rgb("#4a90bd")

// Four bins rather than a ramp, so weight is read off a key. The edges are round
// numbers covering 885 to 9,626 tonnes, and they split the fifteen years
// 3 / 2 / 5 / 5.
//
// The bin is cut here and mapped as a discrete scale, because a binned continuous
// scale draws its guide as one colourbar. Four swatches are what a reader can
// match a circle against.
#let tonne-edges = (2500, 5000, 7500)
#let tonne-labels = ("Under 2,500", "2,500 to 5,000", "5,000 to 7,500", "Over 7,500")
// Four steps, all lighter than the dark theme's page. A ramp running down into
// deep blue separates the bins on white but collapses the top two on black.
// Keeping every step light costs contrast at the pale end, which the ring covers.
#let tonne-colours = (
  rgb("#dceaf4"),
  rgb("#a3c9e2"),
  rgb("#6aa4c9"),
  rgb("#2f7fc4"),
)
#let bin-of(t) = tonne-labels.at(tonne-edges.filter(e => t >= e).len())
#let binned-bins = years.map(y => y + (bin: bin-of(y.tonnes)))

// Label offsets in canvas centimetres, set by hand. Fifteen labels are few
// enough to place one by one, and every automatic rule tried here queued them
// outward and cost the panel height.
//
// Positive x is right, positive y is up. A label is centred on its offset, so a
// sideways one needs about 0.28cm more than an upright one to clear its circle.
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
// defaulting to zero and printing its label on its own circle.
#let binned = binned-bins.map(y => {
  let (dx, dy) = label-nudges.at(y.label)
  y + (nudge-x: dx * 1cm, nudge-y: dy * 1cm)
})

// The thread is shaded along its length, so the excursion reads as a direction.
// The ramp gains saturation and holds its lightness: 2010 leaves grey, 2024
// arrives blue. A pale-to-dark ramp would fail against one page or the other.
#let hop-early = rgb("#b6bac1")
#let hop-late = rgb("#15618f")
#let ink-soft = rgb("#7d838c")

// The page colour the theme resolved, so the key can sit on the panel without
// the grid showing through and still follow the light and dark toggle.
#let paper-colour = theme-minimal().at("paper", default: white)

#let body-font = "Lato"
#let chart-font = "Archivo"

#plot(
  data: binned,
  mapping: aes(x: "arrival", y: "share"),
  layers: (
    geom-curve(
      data: hops,
      mapping: aes(x: "x", y: "y", xend: "xend", yend: "yend", colour: "from"),
      inherit-aes: false,
      curvature: 0.22,
      stroke: 1.1pt,
    ),
    // The ring is the accent colour, not white: white separates circles on the
    // pale page but cuts a bright gap in them on the dark one.
    geom-point(
      mapping: aes(size: "tonnes", fill: "bin"),
      colour: circle-fill,
      alpha: 0.85,
      stroke: 0.5pt,
    ),
    // Each label takes its hand-set offset from `label-nudges`, so placement is a
    // decision on record rather than the output of a layout pass.
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
  // Size and fill say the same thing, so only one key is drawn. It sits in the
  // bottom right, the one corner no circle and no thread reaches. Outside the
  // panel it would cost the caption a line.
  // The thread's ramp gets no key: the fifteen year labels already say it.
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
    // Each line has to fit one rendered line at 6.5 pt across 18 cm, about 150
    // characters. A wrapped caption runs off the bottom of the page.
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
