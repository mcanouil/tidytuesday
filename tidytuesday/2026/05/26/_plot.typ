// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.1.0": *

#let raw = csv("data/energy_cleaned.csv", row-type: dictionary)

#let countries = ("Brazil", "China", "France", "Germany", "United States")
#let data = (
  raw
    .filter(row => row.country_name in countries)
    .map(row => (
      country: row.country_name,
      year: float(row.yr),
      renewable: float(row.renewable_energy_consumption_tfec_pct),
    ))
)

#plot(
  data: data,
  mapping: aes(x: "year", y: "renewable", colour: "country"),
  layers: (geom-line(),),
  labs: labs(
    title: "Renewable share of final energy use, 1990-2010",
    x: "Year",
    y: "Renewable energy (% of final consumption)",
    colour: "Country",
  ),
  theme: theme-minimal(),
  width: 12cm,
  height: 6.3cm,
)
