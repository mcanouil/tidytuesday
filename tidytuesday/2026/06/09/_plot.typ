// Gribouille comes from the typst-render preamble (assets/typst/_preamble.typ),
// so this file does not import it.
// #import "@preview/gribouille:0.7.0": *
// #import "@local/gribouille:0.0.0": *
// #set page(width: 18cm, height: 9.45cm, margin: 0cm)

// Treat every missing sentinel as `none` so a single guard filters them out.
#let num(s) = if s in ("NA", "N/A", "") { none } else { float(s) }

#let raw = csv("data/game_films.csv", row-type: dictionary)

// CinemaScore is an opening-night audience grade. The letters map onto a 0-100
// scale, so it reads against the critic percentage on the same ruler.
#let cinemascore = (
  "A+": 100, "A": 95, "A-": 90,
  "B+": 85, "B": 80, "B-": 75,
  "C+": 70, "C": 65, "C-": 60,
  "D+": 55, "D": 50, "D-": 45,
  "F": 0,
)

// Okabe-Ito accents. Vermillion is money lost and teal is profit, and the fill
// pivots at break-even, where box office equals budget. The accent matches the
// site theme, so the inset border follows the light and dark toggle.
#let loss = rgb("#d55e00")
#let profit = rgb("#009e73")
#let accent = rgb("#0f8b8d")

// Main frame: one currency, so the y axis reads in dollars, and only rows that
// carry a budget and a critic score, so every channel is honest. All of those
// rows are theatrical releases, so shape carries time rather than category.
#let films = (
  raw
    .filter(r => (
      r.worldwide_box_office_currency == "\u{0024}"
        and num(r.worldwide_box_office) != none
        and num(r.budget_high) != none
        and num(r.rotten_tomatoes) != none
        and num(r.release_date.slice(0, 4)) != none
    ))
    .map(r => {
      let box = num(r.worldwide_box_office)
      let bud = num(r.budget_high)
      let yr = int(r.release_date.slice(0, 4))
      let era = if yr >= 2019 { "2019 onward" } else { "Before 2019" }
      (
        title: r.title,
        rt: num(r.rotten_tomatoes),
        box: box,
        budget: bud,
        // The log10 of the profit multiple, so the fill spreads across orders of
        // magnitude and pivots at 0, where box office equals budget.
        logmult: calc.log(box / bud, base: 2),
        era: era,
      )
    })
)

// Inset frame: every film scored by both critics and an opening audience. The
// two means carry the sub-story on their own.
#let scored = raw.filter(r => (
  num(r.rotten_tomatoes) != none and r.cinema_score in cinemascore
))
#let critic-mean = scored.map(r => num(r.rotten_tomatoes)).sum() / scored.len()
#let audience-mean = scored.map(r => cinemascore.at(r.cinema_score)).sum() / scored.len()

// A dumbbell on a 0-100 track: the gap between the critic dot and the audience
// dot is the disagreement. Built from plain Typst primitives, with no nested
// canvas, and it reads `page.fill` to follow the light and dark toggle.
#let inset = context {
  let bg = if page.fill in (auto, none) { white } else { page.fill }
  let w = 4.6cm
  box(
    fill: bg,
    inset: 7pt,
    radius: 4pt,
    stroke: 0.5pt + accent,
  )[
    #set text(size: 7pt)
    #set par(leading: 4pt)
    #align(center)[#strong[Critics pan them; audiences don't]]
    #v(-5pt)
    #box(width: w, height: 8pt)[
      #place(left + horizon, line(length: w, stroke: 0.4pt + luma(75%)))
      #place(
        left + horizon,
        dx: critic-mean / 100 * w,
        line(
          length: (audience-mean - critic-mean) / 100 * w,
          stroke: 1.4pt + luma(55%),
        ),
      )
      #place(
        left + horizon,
        dx: critic-mean / 100 * w - 2.5pt,
        circle(radius: 2.5pt, fill: loss, stroke: none),
      )
      #place(
        left + horizon,
        dx: audience-mean / 100 * w - 2.5pt,
        circle(radius: 2.5pt, fill: profit, stroke: none),
      )
    ]
    #v(-7pt)
    #grid(
      columns: (1fr, 1fr),
      align: (left, right),
      text(fill: loss)[#strong[Critics] (_mean_): #calc.round(critic-mean)],
      text(fill: profit)[#strong[Audiences] (_mean_): #calc.round(audience-mean)],
    )
  ]
}

// A label on a translucent paper background, so the text holds over the marker
// cloud. The background reads `page.fill` to follow the toggle.
#let pill(body) = context {
  let bg = if page.fill in (auto, none) { white } else { page.fill }
  box(
    fill: bg.transparentize(12%),
    inset: (x: 2pt, y: 0.5pt),
    radius: 1.5pt,
  )[#text(size: 7.5pt)[#body]]
}

// A dataset title against the pill to draw for it. The keys pick the films to
// emphasise, and the coordinates come from the inherited frame.
#let label-text = (
  "The Super Mario Bros. Movie": align(center)[*The \ Super Mario Bros. \ Movie*],
  "Pokémon Detective Pikachu": align(center)[*Detective \ Pikachu*],
  "Sonic the Hedgehog 3": align(center)[*Sonic \ the Hedgehog 3*],
  "Postal": align(center)[*Postal* \ (Uwe Boll)],
)

#plot(
  data: films,
  mapping: aes(
    x: "rt",
    y: "box",
    fill: "logmult",
    size: "budget",
    shape: "era",
  ),
  layers: (
    // The "panned but paid" zone: rotten with critics, left of 60, yet past
    // $100M. Painted first, so the points sit on it. A fixed fill on geom-rect
    // keeps it off the continuous fill scale.
    geom-rect(
      data: ((xmin: 0, xmax: 60, ymin: 1e8, ymax: 3e9),),
      mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      fill: accent.transparentize(90%),
      colour: accent,
      stroke: 0.5pt,
      inherit-aes: false,
    ),
    // The Rotten Tomatoes "fresh" threshold.
    annotate(
      "vline",
      xintercept: 60,
      colour: luma(55%),
      stroke: 0.6pt,
      linetype: "dashed",
    ),
    geom-point(alpha: 0.95, stroke: 0.4pt, colour: luma(45%)),
    // An accent outline on the labelled films, so they stand out of the cloud.
    // It inherits the plot mapping, so the ring matches each shape and size.
    geom-point(
      data: d => d.filter(r => r.title in label-text),
      fill: none,
      colour: accent,
      stroke: 1.2pt,
    ),
    // Direct labels rather than a per-film legend. The data function filters the
    // inherited frame and attaches each pill, so the coordinates come from it.
    geom-typst(
      data: d => d
        .filter(r => r.title in label-text)
        .map(r => (..r, lab: pill(label-text.at(r.title)))),
      mapping: aes(x: "rt", y: "box", label: "lab", nudge-y: 0.35),
      anchor: "south",
      inherit-aes: false,
    ),
    // The inset dumbbell sits in the sparse top-left corner, above the cloud.
    annotate("typst", x: 25, y: 1.75e6, label: inset, anchor: "north-west"),
  ),
  scales: scales(
    x: scale-continuous(
      name: "Rotten Tomatoes Critics' Score (%)",
      limits: (0, 100),
      breaks: (0, 20, 40, 60, 80, 100),
    ),
    y: scale-continuous(
      name: "Worldwide Box Office (US$)",
      transform: "log10",
      breaks: (1e5, 1e6, 1e7, 1e8, 1e9),
      labels: ("$100K", "$1M", "$10M", "$100M", "$1B"),
    ),
    fill: scale-gradient2(
      name: "Box Office / Budget Ratio",
      low: loss, mid: rgb("#cfcfcf"), high: profit,
      midpoint: 0,
      breaks: (-6, -4, -2, 0, 2, 4),
      labels: ([$1/64$×], [$1/16$×], [$1/4$×], [$1$×], [$4$×], [$16$×]),
    ),
    size: scale-continuous(
      name: "Production Budget",
      range: (3pt, 10pt),
      breaks: (50e6, 100e6, 200e6),
      labels: ("$50M", "$100M", "$200M"),
    ),
    shape: scale-discrete(
      name: "Release Era",
      limits: ("Before 2019", "2019 onward"),
    ),
  ),

  guides: guides(
    shape: none,
    fill: guide-legend(direction: "horizontal"),
    size: guide-legend(direction: "horizontal"),
  ),
  labels: labels(
    title: "Panned by Critics, Paid by Audiences",
    subtitle: [
      A poor critics' score has rarely stopped a theatrical video-game adaptation
      from making money: most films land #text(fill: profit, weight: "bold")[in profit]
      rather than at a #text(fill: loss, weight: "bold")[loss], the biggest grossers
      carry the biggest budgets, and the runaway hits now belong to the
      post-#emph[Detective Pikachu] boom \
      (#box(rect(width: 4.6pt, height: 4.6pt, fill: luma(55%), stroke: 0.4pt + luma(40%)))~2019 onward,
      not #box(circle(radius: 2.6pt, fill: luma(55%), stroke: 0.4pt + luma(40%)))~before).
    ],
    caption: [
      Source: Films and series based on video games (TidyTuesday 2026-06-09). \
      Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ],
  ),
  theme: theme-minimal(
    panel-grid-minor-y: element-blank(),
  ),
  width: auto,
  height: auto,
)
