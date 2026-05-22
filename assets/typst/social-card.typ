#import "@preview/gribouille:0.1.0": *

// Site dark palette.
#let bg = rgb("#0d1626")
#let ink = rgb("#e7ecf4")
#let muted = rgb("#9fb0c4")
#let teal = rgb("#34d3c2")
#let amber = rgb("#f4b552")
#let green = rgb("#57c89a")
#let surface = rgb("#16223a")

// Species colours matched to the website accents.
#let species-colours = (
  Adelie: amber,
  Chinstrap: teal,
  Gentoo: green,
)

#let species-card(name, note, colour, ink, paper) = context {
  block(
    width: auto,
    inset: 0pt,
    radius: 4pt,
    fill: paper,
    stroke: (paint: colour, thickness: 0.6pt),
  )[
    #set block(spacing: 0pt)

    #block(
      inset: 2pt,
      radius: 4pt,
      fill: colour,
    )[
      #set text(size: 6pt, weight: "bold", fill: if luma(colour)
        .components()
        .at(0)
        < 50% { white } else { black })
      #set par(spacing: 0pt, leading: 0.85em)
      #name
    ]
    #block(inset: (x: 4pt, y: 3pt))[
      #set text(size: 5.4pt, fill: ink)
      #note
    ]
  ]
}

// The Gribouille example figure (Palmer penguins), recoloured to the site
// palette and themed onto the card background.
#let figure = plot(
  data: penguins,
  mapping: aes(
    x: "flipper-len",
    y: "body-mass",
    colour: "species",
    fill: "species",
    shape: "species",
  ),
  layers: (
    geom-point(size: 2pt, alpha: 0.25, stroke: 0.5pt, colour: rgb("#ffffff")),
    geom-mark(method: "hull", expand: 5pt, alpha: 0.25),
    geom-errorbar(stat: stat-summary(fun: "mean-sd"), width: 5pt),
    geom-errorbarh(stat: stat-summary(fun: "mean-sd"), height: 5pt),
    geom-typst(
      data: (
        (x: 183, y: 5000, species: "Adelie", description: "Smallest of the three; white eye-ring."),
        (x: 208, y: 2900, species: "Chinstrap", description: "Thin black band under the chin."),
        (x: 203, y: 6150, species: "Gentoo", description: "Largest brush-tailed; bright orange bill."),
      ),
      mapping: aes(
        x: "x",
        y: "y",
        label: after-stat((row, ctx) => species-card(
          row.species,
          row.description,
          species-colours.at(row.species),
          ctx.theme.at("ink", default: black),
          ctx.theme.at("paper", default: white),
        )),
      ),
    ),
  ),
  scales: (
    scale-x-continuous(),
    scale-y-continuous(labels: format-comma()),
    scale-colour-discrete(limits: species-colours.keys(), palette: species-colours.values()),
    scale-fill-discrete(limits: species-colours.keys(), palette: species-colours.values()),
  ),
  labs: labs(
    title: typst("Penguins *Dataset*"),
    subtitle: "Palmer Archipelago (Antarctica) penguins.",
    colour: "Species",
    fill: "Species",
    shape: "Species",
    x: "Flipper Length (mm)",
    y: "Body Mass (g)",
  ),
  theme: theme-minimal(
    ink: ink,
    paper: surface,
    axis-line: element-line(stroke: 0.5pt),
    tick-length: 0.05cm,
  ),
  guides: guides(colour: guide-none(), fill: guide-none(), shape: guide-none()),
  width: 14cm,
  height: 10.5cm,
)

#set page(width: 1200pt, height: 630pt, margin: 0pt, fill: bg)
#set text(font: "Inter", fill: ink)

// Soft corner glows.
#place(top + right, rect(
  width: 820pt,
  height: 820pt,
  fill: gradient.radial(teal.transparentize(82%), bg.transparentize(100%)),
))
#place(bottom + left, rect(
  width: 700pt,
  height: 700pt,
  fill: gradient.radial(amber.transparentize(88%), bg.transparentize(100%)),
))

// Full-bleed accent bar.
#place(top, rect(width: 100%, height: 8pt, fill: gradient.linear(teal, amber)))

// Figure, right side, in a framed panel.
#place(right + horizon, dx: -48pt, block(
  fill: surface,
  radius: 16pt,
  inset: 16pt,
  stroke: 1pt + teal.transparentize(60%),
  clip: true,
  align(left)[#figure],
))

// Text column, left side, vertically centred.
#place(left + horizon, dx: 80pt, dy: -60pt, block(width: 600pt)[
  #text(size: 24pt, weight: 600, fill: gradient.linear(amber, teal, angle: 8deg), tracking: 4pt)[TIDYTUESDAY]

  // #v(10pt)
  #text(size: 72pt, weight: 800)[Data, drawn \ in #text(fill: teal)[Typst]]

  #v(-40pt)
  #text(size: 26pt, fill: muted)[
    Weekly figures with #text(fill: teal, weight: 600)[Gribouille], \
    #text(style: "italic")[the grammar of graphics for Typst.]
  ]
])

// Footer.
#place(bottom + left, dx: 80pt, dy: -52pt, text(size: 24pt)[
  #text(fill: teal, weight: 600)[m.canouil.dev/tidytuesday]
  #h(14pt) #text(fill: muted)[·] #h(14pt)
  #text(fill: gradient.linear(teal, amber, angle: 8deg))[Mickaël Canouil]
])
