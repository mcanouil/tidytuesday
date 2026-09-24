// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.

// TODO: map the real column names from this CSV.
#plot(
  data: csv("__CSVPATH__", row-type: dictionary),
  mapping: aes(x: "x-column", y: "y-column"),
  layers: (geom-point(),),
  labels: labels(
    title: "__TITLE__",
    caption: [
      Source: TidyTuesday __DATE__. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
    x: "x-column",
    y: "y-column",
  ),
  theme: theme-minimal(),
  width: auto,
  height: auto,
)
