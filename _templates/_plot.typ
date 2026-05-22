// Gribouille is imported by the typst-render preamble (see _quarto.yml);
// do not import it here or the theme-* wrappers get rebound.

// The typst-render extension compiles this file with the repository root as
// the Typst root, so the data path is relative to the repository root.
#let data = csv("__CSVPATH__", row-type: dictionary)

// TODO: map real column names from the CSV above.
#plot(
  data: data,
  mapping: aes(x: "x-column", y: "y-column"),
  layers: (geom-point(),),
  labs: labs(
    title: "__TITLE__",
    x: "x-column",
    y: "y-column",
  ),
  theme: theme-minimal(),
  width: 16cm,
  height: 10cm,
)
