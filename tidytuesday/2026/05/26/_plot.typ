// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.1.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

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

// One-line definition per category, aligned with `cats`. Each rolls up the
// raw columns summed in `reshape`, so the legend names what every band is.
#let cat-labels = (
  [#strong[Traditional biomass] \ wood, charcoal & dung for cooking],
  [#strong[Modern bioenergy] \ biogas, biofuels & waste-to-energy],
  [#strong[Hydropower] \ electricity from flowing water],
  [#strong[Wind & solar] \ plus geothermal & marine],
)

#let accent = rgb("#0f8b8d")

// Box-styled callout: a translucent paper background plus a hairline accent
// border lifts the prose off the stacked bands so it stays legible. The paper
// colour comes from the ambient `page.fill` (typst-render sets the page fill to
// the document background), mirroring how ink is read from `text.fill`, so the
// boxes track the light / dark site toggle.
#let callout(body) = context {
  // `page.fill` is `auto` when the document sets no page fill (standalone
  // compile); typst-render sets it to the background, so fall back to white.
  let bg = if page.fill in (auto, none) { white } else { page.fill }
  box(
    fill: bg.transparentize(12%),
    inset: (x: 5pt, y: 3pt),
    radius: 3pt,
    stroke: 0.5pt + accent.transparentize(45%),
  )[#body]
}

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

#let panel(rows, country, annotations) = defer(
  plot,
  data: rows,
  mapping: aes(x: "year", ymin: "ymin", ymax: "ymax", fill: "category"),
  layers: (geom-ribbon(alpha: 1),) + annotations,
  scales: (
    scale-x-continuous(breaks: (1990, 2000, 2010)),
    scale-fill-discrete(limits: cats, palette: cat-colours.values(), labels: cat-labels),
  ),
  labs: labs(title: country, x: none, y: "% Final Energy", fill: none),
  theme: theme-minimal(),
)

// In-panel callouts: the total renewable share at each end, plus a one-line
// "why" sitting in the empty corner of each panel. Text colour is left to the
// theme ink so the callouts track the light / dark site toggle.
#let vn-annot = (
  annotate("label", x: 1990.2, y: 79, label: "76%", size: 9pt, anchor: "west"),
  annotate("label", x: 2009.8, y: 42, label: "35%", size: 9pt, anchor: "east"),
  annotate(
    "typst",
    x: 2009.6,
    y: 70,
    label: callout[
      #text(
        fill: cat-colours.at("Traditional biomass"),
        weight: "semibold"
      )[Traditional biomass] #emph[for cooking] \
      #emph[fades as fossil fuels spread]
    ],
    size: 6.5pt,
    anchor: "east",
  ),
)
#let de-annot = (
  annotate("label", x: 1990.2, y: 2.5, label: "2%", size: 9pt, anchor: "west"),
  annotate("label", x: 2009.8, y: 11.4, label: "11%", size: 9pt, anchor: "east"),
  annotate(
    "typst",
    x: 1990.2,
    y: 9.6,
    label: callout[
      #text(
        fill: cat-colours.at("Modern bioenergy"),
        weight: "semibold"
      )[Modern bioenergy],
      #emph[then]
      #text(
        fill: cat-colours.at("Wind & solar"),
        weight: "semibold"
      )[wind & solar], \
      #emph[built from almost nothing]
    ],
    size: 6.5pt,
    anchor: "west",
  ),
)

#let panels = compose(
  panel(vn, "Vietnam", vn-annot),
  panel(de, "Germany", de-annot),
  layout: "grid",
  columns: 2,
  collect: ("fill",),
  guides: guides(default: guide-legend(position: "bottom")),
  gutter: 1cm,
  labs: labs(
    title: "What \"Renewable Energy\" Means Depends on How Rich a Country Is",
    subtitle: "Renewable share of final energy use, by source, 1990 to 2010.",
    caption: typst([
      Source: Sustainable Energy for All (TidyTuesday 2026-05-26). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ])
  ),
)

#box[
  #panels
  #place(top + center, dx: 0pt, dy: 2cm)[
    #set align(center)
    #set text(size: 8pt, style: "italic", fill: accent)
    As incomes rise, \ two roads diverge
    #v(2pt)
    #box(inset: (x: 2pt))[
      #text(size: 40pt, fill: cat-colours.at("Traditional biomass"))[↓]
      #h(4pt)
      #text(size: 40pt, fill: cat-colours.at("Wind & solar"))[↑]
    ]
  ]
]
