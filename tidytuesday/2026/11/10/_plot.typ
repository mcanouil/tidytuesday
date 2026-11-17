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
#assert(calc.round(all-shown * 100) == 59, message: "the printed overall share of shown citations changed")

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
#let none-colour = ink.transparentize(100%)

#let sans = "IBM Plex Sans"
#let mono = "IBM Plex Mono"

#let page-colour = theme-minimal().at("paper", default: white)
#let row-height = 0.34cm

// A bar of the evidence behind a franchise's ranking, one stacked segment for
// each kind. Gribouille's `nanoplot` takes no `coord`, so `geom-col` cannot be
// turned on its side here, and the segments are rects on the share scale.
#let bar-width = 2.9cm
#let stack-order = ("stated", "shown", "scaled")
#let bar-cells(f) = (
  stack-order
  .enumerate()
  .filter(((i, k)) => f.at(k) > 0)
  .map(((i, k)) => {
    let start = stack-order.slice(0, i).map(before => f.at(before)).sum(default: 0)
    (kind: k, xmin: start, xmax: start + f.at(k), ymin: 0, ymax: 1)
  })
)
#let bar-plot = nanoplot(
  mapping: aes(xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax", fill: "kind"),
  layers: (geom-rect(colour: page-colour, stroke: 0.6pt),),
  scales: scales(
    x: scale-continuous(expand: (0%, 0%)),
    y: scale-continuous(limits: (0, 1), expand: (0%, 0%)),
    fill: scale-manual(values: kinds.map(k => colours.at(k)), limits: kinds),
  ),
  domain-field: "xmax",
  axis: false,
)

#let shown-share(share) = text(font: mono, size: 6.5pt, fill: ink)[#calc.round(share * 100)%]
#let citations(n) = text(font: mono, size: 5.5pt, fill: muted)[#n]

// A strip with one dot for each recorded death, the undone ones last. Every
// strip shares one scale, so a dot has the same width in every row. A franchise with no death gets a label in place of a dot.
#let most-deaths = calc.max(..franchises.map(f => f.fallen))
#let deaths-width = 5.6cm
#let death-cells(f) = if f.fallen == 0 {
  ((x: 1, y: 0, kind: "none", label: "none recorded"),)
} else {
  range(f.fallen).map(i => (x: i + 1, y: 0, label: none, kind: if i >= f.fallen - f.undone { "undone" } else { "stands" }))
}
#let deaths-plot = nanoplot(
  mapping: aes(x: "x", y: "y", fill: "kind", label: "label"),
  layers: (
    geom-point(size: 1.0pt, stroke: none),
    geom-text(anchor: "west", nudge-x: 0.3, font: sans, size: 6pt, colour: muted),
  ),
  scales: scales(
    x: scale-continuous(expand: (0%, 0%)),
    y: scale-continuous(limits: (-1, 1), expand: (0%, 0%)),
    fill: scale-manual(
      values: (colours.undone, stands-colour, none-colour),
      limits: ("undone", "stands", "none"),
    ),
  ),
  domain-field: "x",
  axis: false,
  
)

#let key(fill, label) = [#text(fill: fill)[■] #label#h(9pt)]

#let rows = franchises.map(f => (franchise: f.name, medium: f.medium, evidence: bar-cells(f), shown: f.shown, n: f.n, deaths: death-cells(f)))

#let figure-table(width) = {
  let medium-width = 2.5cm
  let evidence-width = bar-width + 6pt
  let shown-width = 0.95cm
  let n-width = 1.3cm
  let deaths-column = deaths-width + 6pt
  keisen.display-table(
    rows,
    keisen.table-header(
      title: text(font: sans, size: 14pt, weight: "bold")[Berserk Shows Its Feats, Dungeons & Dragons Only States Them],
      subtitle: text(font: sans, size: 7pt)[
        The bar splits the citations behind a franchise's ranking by the evidence they give: shown on page or screen, stated by a character or a guidebook, or scaled against another feat.
        Each dot is a death that a ranked character caused.\
        Evidence: #key(colours.stated, "stated")#key(colours.shown, "shown")#key(colours.scaled, "scaled")\
        Deaths: #key(colours.undone, "undone later")#key(stands-colour, "left standing")
      ],
    ),
    keisen.table-stub(rowname: "franchise", label: [Franchise]),
    keisen.columns-label(
      medium: [Main medium],
      evidence: [Evidence],
      shown: [Shown],
      n: [Citations],
      deaths: [Recorded deaths],
    ),
    keisen.columns-align(start, columns: ("evidence", "deaths")),
    keisen.columns-align(end, columns: ("shown", "n")),
    keisen.columns-width((franchise: width - medium-width - evidence-width - shown-width - n-width - deaths-column, medium: medium-width, evidence: evidence-width, shown: shown-width, n: n-width, deaths: deaths-column)),
    keisen.format-nanoplot("evidence", plot: bar-plot, width: bar-width, height: row-height, domain: (0, 1)),
    keisen.format("shown", shown-share),
    keisen.format("n", citations),
    keisen.format-nanoplot("deaths", plot: deaths-plot, width: deaths-width, height: row-height, domain: (0.5, most-deaths + 2.5)),
    keisen.table-source-note(text(font: sans, size: 5.5pt)[
      Franchises run from the lowest share of shown citations at the top to the highest at the bottom. Across all #total-of(characters, "citations") citations, #calc.round(all-shown * 100)% are shown.
      The ranks and grades are the editorial judgements of Cited Feats, and the deaths are only those that ranked characters caused.
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

#fit-page((width, height) => figure-table(width))
