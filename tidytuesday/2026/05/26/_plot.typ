// Gribouille is imported by the typst-render preamble (see _quarto.yml);
// do not import it here or the theme-* wrappers get rebound.

// The typst-render extension compiles this file with the repository root as
// the Typst root, so the data path is relative to the repository root.
#let raw = csv("tidytuesday/2026/05/26/data/energy_cleaned.csv", row-type: dictionary)

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
    title: "Renewable share of final energy use, 1990–2010",
    x: "Year",
    y: "Renewable energy (% of final consumption)",
    colour: "Country",
  ),
  theme: theme-minimal(),
  width: 18cm,
  height: 11cm,
)
