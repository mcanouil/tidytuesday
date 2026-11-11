// Gribouille and Keisen come from the typst-render preamble
// (assets/typst/_preamble.typ), so this file does not import them.

// One row per ranked character. `shown`, `stated` and `scaled` count the
// citations behind the placement by the kind of evidence they give: shown on
// page or screen, stated by a character, a narrator or a guidebook, or scaled by
// comparison with someone else's feat.
// Source: data/fiction_rankings.csv and data/fiction_deaths.csv (TidyTuesday 2026-11-10).
#let characters = csv("data/fiction_rankings.csv", row-type: dictionary)
#let deaths = csv("data/fiction_deaths.csv", row-type: dictionary)

#let kinds = ("shown", "stated", "scaled")
#let total-of(rows, kind) = rows.map(r => int(r.at(kind))).sum()

#assert(
  characters.all(r => int(r.citations) == kinds.map(k => int(r.at(k))).sum()),
  message: "a character no longer has citations equal to shown, stated and scaled together",
)

// The medium that most of a franchise's characters come from.
#let main-medium(rows) = {
  let media = rows.map(r => r.media).dedup()
  let best = media.sorted(key: m => -rows.filter(r => r.media == m).len()).first()
  let words = best.split(";")
  upper(words.first().at(0)) + words.first().slice(1) + words.slice(1).map(w => ", " + w).join()
}

#let franchises = {
  characters
    .map(r => r.franchise)
    .dedup()
    .map(f => {
      let rows = characters.filter(r => r.franchise == f)
      let n = total-of(rows, "citations")
      let slug = rows.first().franchise_slug
      let fallen = deaths.filter(d => d.franchise_slug == slug)
      (
        name: f,
        medium: main-medium(rows),
        n: n,
        fallen: fallen.len(),
        undone: fallen.filter(d => d.undone == "TRUE").len(),
        ..kinds.map(k => (k, total-of(rows, k) / n)).to-dict(),
      )
    })
    .sorted(key: f => f.shown)
}
#let franchise(name) = franchises.find(f => f.name == name)

#assert(franchises.len() == 21, message: "the number of franchises changed")
#assert(
  (franchises.first().name, franchises.last().name) == ("Dungeons & Dragons", "Berserk"),
  message: "the franchise with the lowest or the highest share of shown citations changed",
)
#assert(
  (franchise("Berserk"), franchise("Dungeons & Dragons")).map(f => calc.round(f.shown * 100)) == (95, 13),
  message: "the printed share of shown citations changed",
)
#assert(
  total-of(characters, "scaled") == 2 and total-of(characters, "citations") == 1746,
  message: "the number of scaled or of all citations changed",
)
#assert(
  deaths.len() == 307 and deaths.filter(d => d.undone == "TRUE").len() == 40,
  message: "the number of deaths or of undone deaths changed",
)
#assert(
  ("Marvel", "Solo Leveling", "Overlord", "Westeros").map(f => (franchise(f).fallen, franchise(f).undone))
    == ((49, 13), (39, 9), (20, 5), (67, 2)),
  message: "the printed deaths or undone deaths of a franchise changed",
)
#assert(
  deaths.all(d => d.franchise_slug in characters.map(r => r.franchise_slug)),
  message: "a death belongs to a franchise that has no ranking",
)
#let all-shown = total-of(characters, "shown") / total-of(characters, "citations")

#let ink = theme-minimal().at("ink", default: black)
#let dark = ink.oklab().components().first() > 50%
#let muted = ink.transparentize(35%)

// Blue for what is shown, orange for what is only said, and a quiet grey for the
// two scaled citations. Teal marks a death that the story took back. Each set
// passes validate_palette.js against its own page, #fbfaf7 or #0d1626.
#let colours = if dark {
  (shown: rgb("#5a8fd8"), stated: rgb("#d07a2c"), scaled: ink.transparentize(55%), undone: rgb("#34a083"))
} else {
  (shown: rgb("#2f6bb8"), stated: rgb("#c2510e"), scaled: ink.transparentize(55%), undone: rgb("#1f8a70"))
}
#let stands-colour = ink.transparentize(65%)

#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

#let bar-width = 2.9cm
#let bar-column-width = bar-width + 1.9cm
#let bar(name) = {
  let f = franchise(name)
  let gap = 0.6pt
  box(width: bar-column-width, height: 0.34cm)[
    #place(horizon + left, stack(
      dir: ltr,
      spacing: gap,
      ..kinds.filter(k => f.at(k) > 0).map(k => rect(width: bar-width * f.at(k) - gap, height: 0.34cm, fill: colours.at(k), stroke: none)),
    ))
    #place(horizon + left, dx: bar-width + 5pt, text(font: mono, size: 6.5pt, fill: ink)[#calc.round(f.shown * 100)%])
    #place(horizon + left, dx: bar-width + 1.05cm, text(font: mono, size: 5.5pt, fill: muted)[of #f.n])
  ]
}

#let mark-size = 2.3pt
#let mark-step = 2.7pt
#let marks-width = 67 * mark-step + 9pt
#let fallen(name) = {
  let f = franchise(name)
  if f.fallen == 0 {
    text(font: sans, size: 6pt, fill: muted)[none recorded]
  } else {
    box(width: marks-width, height: 0.34cm)[
      #place(horizon + left, stack(
        dir: ltr,
        spacing: mark-step - mark-size,
        ..range(f.fallen).map(i => circle(
          radius: mark-size / 2,
          fill: if i >= f.fallen - f.undone { colours.undone } else { stands-colour },
          stroke: none,
        )),
      ))
    ]
  }
}

#let key(fill, label) = box(baseline: 1pt)[
  #box(rect(width: 7pt, height: 7pt, fill: fill, stroke: none), baseline: 0.5pt)
  #text(size: 6.5pt)[ #label#h(9pt)]
]

#let rows = franchises.map(f => (franchise: f.name, medium: f.medium, evidence: f.name, deaths: f.name))

#let figure-table(width) = {
  let medium-width = 2.3cm
  let evidence-width = bar-column-width + 6pt
  let deaths-width = marks-width + 6pt
  keisen.display-table(
    rows,
    keisen.table-header(
      title: text(font: sans, size: 14pt, weight: "bold")[Berserk Shows Its Feats, Dungeons & Dragons Only States Them],
      subtitle: text(font: sans, size: 7pt)[
        The bar splits the citations behind a franchise's ranking by the evidence they give: shown on page or screen, stated by a character or a guidebook, or scaled against another feat.
        The number after the bar is the count of citations.
        Each dot is a death recorded against a ranked character.\
        Evidence: #key(colours.shown, "shown")#key(colours.stated, "stated")#key(colours.scaled, "scaled")\
        Deaths: #key(colours.undone, "undone later")#key(stands-colour, "left standing")
      ],
    ),
    keisen.table-stub(rowname: "franchise", label: [Franchise]),
    keisen.columns-label(
      medium: [Main medium],
      evidence: [Evidence behind the ranking],
      deaths: [Recorded deaths],
    ),
    keisen.columns-align(start, columns: ("evidence", "deaths")),
    keisen.columns-width((franchise: width - medium-width - evidence-width - deaths-width, medium: medium-width, evidence: evidence-width, deaths: deaths-width)),
    keisen.format("evidence", bar),
    keisen.format("deaths", fallen),
    keisen.table-source-note(text(font: sans, size: 5.5pt)[
      Franchises run from the lowest share of shown citations at the top to the highest at the bottom. Across all #total-of(characters, "citations") citations, #calc.round(all-shown * 100)% are shown.
      The ranks and grades are the editorial judgements of Cited Feats, and the deaths are only those recorded against ranked characters.
      Source: TidyTuesday 2026-11-10. Author: #link("https://mickael.canouil.fr")[Mickaël CANOUIL].
    ]),
    keisen.table-options(
      table-font: sans,
      table-font-size: 7pt,
      table-width: width,
      cell-inset: 2.6pt,
      cell-vertical-align: horizon,
      column-labels-border-bottom: 0.5pt + muted,
      column-labels-size: 6.5pt,
      stub-weight: "medium",
    ),
    theme: keisen.theme-minimal(),
  )
}

// The table keeps its natural height and is only scaled down when the page is
// shorter, so the featured image shows the same figure as plot.svg.
#layout(size => {
  let table = figure-table(size.width)
  let height = measure(width: size.width, table).height
  if height > size.height {
    align(center + horizon, scale(size.height / height * 100%, reflow: true, table))
  } else {
    table
  }
})
