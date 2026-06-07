// Gribouille is imported by the typst-render preamble (see assets/typst/_preamble.typ);
// do not import it here or the theme-* wrappers get rebound.
// #import "@preview/gribouille:0.1.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

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
  width: auto,
  height: auto,
)
