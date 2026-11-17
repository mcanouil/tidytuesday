// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// One row per sofa or armchair listed on ikea.com in one country, with its price
// in US dollars. `item_no` identifies the same product across countries.
// Source: data/ikea_seating.csv (TidyTuesday 2026-10-27).
#let listings = csv("data/ikea_seating.csv", row-type: dictionary)

#let min-countries = 30

// price-of[item][country]: the first listed price of an item in a country.
#let price-of = {
  let found = (:)
  for l in listings {
    let in-item = found.at(l.item_no, default: (:))
    if l.country not in in-item {
      in-item.insert(l.country, float(l.price_usd))
      found.insert(l.item_no, in-item)
    }
  }
  found
}

// A price index: an item's price in a country divided by the median price of the
// same item over all the countries that list it. Only items on sale in
// `min-countries` countries or more are compared.
#let shared-items = price-of.keys().filter(i => price-of.at(i).len() >= min-countries)
#let index-of = {
  let found = (:)
  for item in shared-items {
    let prices = price-of.at(item)
    let typical = median(prices.values()).y
    for (country, price) in prices {
      found.insert(country, found.at(country, default: ()) + (price / typical,))
    }
  }
  found
}

#let names = (
  ae: "United Arab Emirates", at: "Austria", au: "Australia", be: "Belgium", bh: "Bahrain", ca: "Canada",
  ch: "Switzerland", cl: "Chile", co: "Colombia", cz: "Czechia", de: "Germany", dk: "Denmark", ee: "Estonia",
  eg: "Egypt", es: "Spain", fi: "Finland", fr: "France", gb: "United Kingdom", hr: "Croatia", hu: "Hungary",
  ie: "Ireland", il: "Israel", "in": "India", it: "Italy", jo: "Jordan", jp: "Japan", kr: "South Korea",
  kw: "Kuwait", lt: "Lithuania", lv: "Latvia", ma: "Morocco", mx: "Mexico", my: "Malaysia", nl: "Netherlands",
  no: "Norway", nz: "New Zealand", om: "Oman", ph: "Philippines", pl: "Poland", pt: "Portugal", qa: "Qatar",
  ro: "Romania", rs: "Serbia", sa: "Saudi Arabia", se: "Sweden", sg: "Singapore", si: "Slovenia", sk: "Slovakia",
  th: "Thailand", us: "United States",
)

// Countries from the dearest at the top to the cheapest at the bottom.
#let countries = {
  index-of
    .pairs()
    .map(((code, ratios)) => {
      let spread = quantiles(ratios)
      (name: names.at(code), n: ratios.len(), mid: spread.y, low: spread.ymin, high: spread.ymax)
    })
    .sorted(key: c => c.mid)
}

#assert(shared-items.len() == 111, message: "the number of items sold in 30 countries or more changed")
#assert(countries.len() == 50, message: "the number of countries changed")
#assert(
  (calc.min(..countries.map(c => c.n)), calc.max(..countries.map(c => c.n))) == (32, 107),
  message: "the number of products compared in a country changed",
)
#assert(
  (countries.first().name, countries.last().name) == ("Thailand", "Mexico"),
  message: "the cheapest or the dearest country changed",
)
#assert(
  (calc.round(countries.first().mid, digits: 2), calc.round(countries.last().mid, digits: 2)) == (0.76, 1.65),
  message: "the printed price index of the cheapest or the dearest country changed",
)
#assert(countries.last().mid / countries.first().mid > 2, message: "Mexico is no longer more than twice as dear as Thailand")
#assert(
  countries.all(c => c.low > 0.55 and c.high < 2.1),
  message: "an interval now falls outside the range the price axis was drawn for",
)
#let dearer = countries.filter(c => c.mid > 1)
#assert(dearer.len() == 22, message: "the number of countries above the typical price changed")

#let ink = theme-minimal().at("ink", default: black)
#let dark = ink.oklab().components().first() > 50%
#let muted = ink.transparentize(35%)

// Orange above the typical price, blue below it. Each pair passes
// validate_palette.js against its own page, #fbfaf7 or #0d1626.
#let cheaper = if dark { rgb("#5a8fd8") } else { rgb("#2f6bb8") }
#let dearer-colour = if dark { rgb("#d07a2c") } else { rgb("#c2510e") }

#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

// One row per product and country, so Gribouille summarises each country itself.
#let rows = {
  index-of
  .pairs()
  .map(((code, ratios)) => ratios.map(r => (
    name: names.at(code),
    ratio: r,
    side: if countries.find(c => c.name == names.at(code)).mid > 1 { "dearer" } else { "cheaper" },
  )))
  .flatten()
}
#let ratio-label(v) = text(font: mono, size: 6pt, fill: muted)[#format-number(digits: 2)(v)\×]
#let breaks = (0.6, 0.8, 1, 1.25, 1.6, 2)

#let figure-plot(width, height) = plot(
  data: rows,
  mapping: aes(x: "name", y: "ratio", colour: "side"),
  layers: (
    // The typical price. geom-hline and geom-vline widen the price axis under
    // coord-flip, so a segment across every row draws it.
    geom-segment(
      data: ((x: 0.4, xend: countries.len() + 0.6, y: 1, yend: 1),),
      mapping: aes(x: "x", xend: "xend", y: "y", yend: "yend"),
      inherit-aes: false,
      colour: muted, stroke: 0.6pt, linetype: "dashed",
    ),
    // The price axis spans 0.55 to 2.1 as before. A y limit cannot do it: under
    // coord-flip it removes the layers that summarise the products.
    geom-blank(
      data: (0.55, 2.1).map(v => (name: countries.first().name, ratio: v)),
      mapping: aes(x: "name", y: "ratio"),
      inherit-aes: false,
    ),
    // The line spans the middle half of the products, and the dot is the median.
    geom-linerange(
      stat: stat-summary(fun: "median-hilow", fun-args: (conf: 0.5)),
      stroke: 2.4pt,
      alpha: 0.7,
    ),
    geom-pointrange(
      stat: stat-summary(fun: "median-hilow", fun-args: (conf: 0.5)),
      size: 3pt,
      stroke: 0pt,
    ),
  ),
  coord: coord-flip(),
  scales: scales(
    x: scale-discrete(limits: countries.rev().map(c => c.name)),
    y: scale-log10(breaks: breaks, labels: ratio-label),
    colour: scale-manual(values: (dearer-colour, cheaper), limits: ("dearer", "cheaper")),
  ),
  labels: labels(
    title: "A Typical IKEA Sofa Costs More Than Twice as Much in Mexico as in Thailand",
    subtitle: [
      Each dot is a country's median price as a multiple of the median price of the same product over all countries.\
      The line spans the middle half of the #calc.min(..countries.map(c => c.n)) to #calc.max(..countries.map(c => c.n)) products compared in a country.\
      The dashed line is the typical price, and #dearer.len() countries sit above it.
    ],
    caption: [
      Prices in US dollars on ikea.com, 28 September 2026, for the #shared-items.len() sofas and armchairs sold in #min-countries or more of the 50 countries.\
      Source: TidyTuesday 2026-10-27. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: none,
    y: none,
  ),
  guides: guides(default: none),
  theme: theme-minimal(
    plot-title: element-text(font: sans, size: 13pt, weight: "bold", colour: ink),
    plot-subtitle: element-text(font: sans, size: 7pt, colour: ink),
    plot-caption: element-text(font: sans, size: 5.5pt, colour: muted),
    axis-text-y: element-text(font: sans, size: 6.5pt, colour: ink),
  ),
  width: width,
  height: height,
)

// Keep natural-height equal to the height of the plot.svg block in index.qmd.
#fit-page(figure-plot, natural-height: 16cm)
