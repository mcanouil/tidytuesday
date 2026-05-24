// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.1.0": *
// #import "@local/gribouille:0.0.0": *

#let num(s) = if s == "NA" or s == "" { 0.0 } else { float(s) }

#let raw = csv("data/energy_cleaned.csv", row-type: dictionary)

// Four mutually exclusive, exhaustive slices of the renewable total (% of final
// energy). One dictionary keeps each category bound to its Okabe-Ito colour, so
// labels, the stacking order, and the legend can never drift out of sync.
// Okabe-Ito is colourblind-safe; warm "old" biomass through cool "new" turbines.
#let cat-colours = (
  "Traditional biomass": rgb("#e69f00"),
  "Modern bioenergy": rgb("#009e73"),
  "Hydropower": rgb("#56b4e9"),
  "Wind & solar": rgb("#0072b2"),
)
#let cats = cat-colours.keys()

// One row per (year, category) carrying the stacked band bounds (ymin, ymax).
// geom-area draws every band from y = 0, so stacked areas would paint over one
// another; geom-ribbon with explicit bounds is the honest stacking primitive.
#let reshape(country) = {
  raw
    .filter(row => row.country_name == country)
    .map(row => {
      let y = float(row.yr)
      let shares = (
        "Traditional biomass": num(row.traditional_biomass_consumption_tfec_pct),
        "Modern bioenergy": num(row.modern_biomass_energy_consumption_tfec_pct)
          + num(row.biogas_consumption_tfec_pct)
          + num(row.liquid_biofuels_energy_consumption_tfec_pct)
          + num(row.waste_energy_consumption_tfec_pct),
        "Hydropower": num(row.hydro_energy_consumption_tfec_pct),
        "Wind & solar": num(row.wind_energy_consumption_tfec_pct)
          + num(row.solar_energy_consumption_tfec_pct)
          + num(row.geothermal_energy_consumption_tfec_pct)
          + num(row.marine_energy_consumption_tfec_pct),
      )
      cats
        .fold((acc: 0.0, out: ()), (st, c) => {
          let hi = st.acc + shares.at(c)
          (
            acc: hi,
            out: st.out + ((year: y, category: c, ymin: st.acc, ymax: hi),),
          )
        })
        .out
    })
    .flatten()
}

#let vn = reshape("Vietnam")
#let de = reshape("Germany")

// One ribbon layer per category: gribouille's ribbon does not split on a group
// aesthetic, so each band is its own filtered layer. The shared fill scale still
// trains across all layers, keeping the colour mapping consistent.
#let bands(rows) = cats.map(c => geom-ribbon(
  data: rows.filter(r => r.category == c),
  alpha: 0.92,
))

#let panel(rows, country, annotations) = plot(
  data: rows,
  mapping: aes(x: "year", ymin: "ymin", ymax: "ymax", fill: "category"),
  layers: bands(rows) + annotations,
  scales: (
    scale-x-continuous(breaks: (1990, 2000, 2010)),
    scale-fill-discrete(limits: cats, palette: cat-colours.values()),
  ),
  labs: labs(title: country, x: none, y: "% of final energy"),
  theme: theme-minimal(),
  guides: guides(fill: guide-none()),
  width: 6.6cm,
  height: 6cm,
  defer: true,
)

// In-panel callouts: the total renewable share at each end, plus a one-line
// "why" sitting in the empty corner of each panel. Text colour is left to the
// theme ink so the callouts track the light / dark site toggle.
#let vn-annot = (
  annotate("text", x: 1990.2, y: 79, label: "76%", size: 9pt, anchor: "west"),
  annotate("text", x: 2009.8, y: 39, label: "35%", size: 9pt, anchor: "east"),
  annotate(
    "text",
    x: 2009.6,
    y: 70,
    label: "Traditional biomass for cooking",
    size: 6.5pt,
    anchor: "east",
  ),
  annotate(
    "text",
    x: 2009.6,
    y: 65,
    label: "fades as fossil fuels spread",
    size: 6.5pt,
    anchor: "east",
  ),
)
#let de-annot = (
  annotate("text", x: 1990.2, y: 1.2, label: "2%", size: 9pt, anchor: "west"),
  annotate("text", x: 2009.8, y: 11.4, label: "11%", size: 9pt, anchor: "east"),
  annotate(
    "text",
    x: 1990.2,
    y: 9.6,
    label: "Modern bioenergy, then",
    size: 6.5pt,
    anchor: "west",
  ),
  annotate(
    "text",
    x: 1990.2,
    y: 8.9,
    label: "wind & solar, built from",
    size: 6.5pt,
    anchor: "west",
  ),
  annotate(
    "text",
    x: 1990.2,
    y: 8.2,
    label: "almost nothing",
    size: 6.5pt,
    anchor: "west",
  ),
)

#let accent = rgb("#0f8b8d")

#let panels = compose(
  panel(vn, "Vietnam", vn-annot),
  panel(de, "Germany", de-annot),
  layout: "grid",
  columns: 2,
  collect: none,
  guides-placement: "bottom",
  gutter: 1.6cm,
)

// Manual, order-controlled legend (compose's hoisted legend clips its first
// swatch). Drawn from the same dictionary, so it always matches the bands.
// Workaround awaiting upstream fix.
#let swatch(c) = box(
  baseline: 1pt,
  rect(width: 9pt, height: 9pt, radius: 1pt, fill: cat-colours.at(c)),
)
#let legend = align(center)[
  #set text(size: 8pt)
  #cats.map(c => box[#swatch(c) #h(3pt) #c]).join(h(16pt))
]

#block(width: auto)[
  #text(size: 13pt, weight: 700)[
    What "renewable energy" means depends on how rich a country is
  ]

  #context text(size: 9pt, fill: text.fill.transparentize(20%))[
    Renewable share of final energy use, by source, 1990 to 2010
  ]

  #v(0pt)

  // compose() lays the two panels in a grid; the linking annotation is placed
  // over the gutter between them, with arrows tracing each opposite trend.
  #box[
    #panels
    #place(center + horizon, dx: -7pt, dy: -16pt)[
      #set align(center)
      #set text(size: 7.5pt, style: "italic", fill: accent)
      As incomes rise, \ two roads diverge
      #v(2pt)
      #box(inset: (x: 2pt))[
        #text(size: 13pt, fill: cat-colours.at("Traditional biomass"))[↓]
        #h(4pt)
        #text(size: 13pt, fill: cat-colours.at("Wind & solar"))[↑]
      ]
    ]
  ]

  #v(-25pt)
  #legend

  #v(5pt)
  #context text(size: 7pt, fill: text.fill.transparentize(35%))[
    Source: Sustainable Energy for All (TidyTuesday 2026-05-26). Bands sum to each
    country's total renewable share; panels use independent vertical scales.
  ]
]
