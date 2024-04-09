#import "titlepage.typ": titlepage

// Change the default heading supplement based on the depth
//
// The supplement uses the `text.lang` in the current context.
// Only the languages "en" (English) and "de" (German) are supported.
//
// This function is supposed to be used in the set rule for headings
// ```
// set heading(supplement: heading-supplement)`
// ```
#let heading-supplement(it) = context {
  if text.lang == "en" {
    ([Chapter], [Section], [Subsection]).at(it.depth - 1, default: [])
  } else if text.lang == "de" {
    ([Kapitel], [Abschnitt], [Unterabschnitt]).at(it.depth - 1, default: [])
  }
}

// Find the pages where a certain label is used
//
// - name (label): Label to query
// -> array of int
//
// Wrapping the label `name` in a `selector()` would only be necessary to use
// the modifiers `.or()`, `.and()`, `.before()` or `.after()`.
#let find-labels(name) = {
  query(name).map(label => label.location().page())
}

// Modified page header to display heading information
//
// This is supposed to be passed to the set rule of the page 
// ```
// set page(header: page-header)
// ```
//
// By comparing the current `here().page()` in the context to the pages where
// the <empty-page> and <new-chapter> labels are placed, the header is hidden
// on pages where a new chapter starts and on empty pages that are inserted to
// ensure that a new chapter starts on an odd page.
// The header is also hidden on all pages where a heading with the <outline>
// label is found. And if the heading numbering is (currently) set to none,
// the header is also hidden. This is mainly intended for outline chapters,
// but it could also be used elsewhere.
//
// On all pages that show a header, the content alternates between the current
// chapter name and the current section name. On even pages the chapter is
// displayed with a 'left' alignment and on odd pages the section is displayed
// with a 'right' alignment.
#let page-header = context {
  let empty-pages = find-labels(<empty-page>)
  let new-chapters = find-labels(<new-chapter>)
  if new-chapters.len() > 0 {
    if new-chapters.contains(here().page()) { return none }

    let new-chapter-index = new-chapters.position(page => page > here().page())
    if new-chapter-index != none {
      let empty-page = empty-pages.at(new-chapter-index)
      if empty-page < here().page() { return none }
    }
  }

  let outlines = find-labels(<outline>)
  if outlines.contains(here().page()) { return none }
  // select all headings there to include pages in outline chapters
  let chapters = query(selector(heading.where(depth: 1)).before(here()))
  if chapters.len() == 0 or chapters.last().numbering == none { return none }

  set text(10pt)
  let _underline = move(dx: 0pt, dy: -0.7em, line(length: 100%))

  let (page-count, ) = counter(page).get()
  if calc.even(page-count) {
    let chapter = chapters.last()
    let chapter-number = counter(selector(heading.where(depth: 1))).display()
    return chapter.supplement + " " + chapter-number + h(0.7em) + chapter.body + _underline
  }

  // select all chapters (depth = 1) and sections (depth = 2) to conserve the
  // actual order of the headings which ignoring (sub)subsections with depth > 2
  let chapter-section-selector = selector(heading.where(depth: 1).or(heading.where(depth: 2)))
  let headings = query(chapter-section-selector.before(here()))
  if (headings.last().depth == 1) { return none }

  let section = headings.last()
  // using the selector(heading.where(depth: 2)) will just count the sections on their own
  // instead of the sections numbers 1.1, 1.2, 2.1 the output will be 0.1, 0.2, 0.3
  // the chapter-section-selector will ensure that the correct section number is used
  let section-number = counter(chapter-section-selector).display()
  return h(1fr) + section.supplement + " " + section-number + h(0.7em) + section.body + _underline
}

#let page-footer = context {
  // compared to the header, the footer is only supposed to be omitted on empty pages
  // the pages with the <new-chapter> label therefore have to be conserved 
  //
  // since the page breaks in chapter-heading() are inserted after the <empty-page> label,
  // the selector has to look "before" the current page to find the relevant label
  let empty-page-labels = query(selector(<empty-page>).before(here()))
  if empty-page-labels.len() > 0 {
    let empty-page = empty-page-labels.last().location().page()
    // look back at the most recent <new-chapter> label
    let new-chapter = query(selector(<new-chapter>).before(here())).last().location().page()
    // check that there is no <new-chapter> label on the current page
    if (new-chapter != here().page()) and (empty-page + 1 == here().page()) {
      return
    }
  }

  // left/right align the page number on even/odd pages
  let page-display = counter(page).display(here().page-numbering())
  return if calc.even(here().page()) { page-display } else { h(1fr) + page-display }
}

// labels can only be used in markup mode
#let chapter-heading(it) = [
  #let (page-count, ) = counter(page).get()
  #[] <empty-page>
  #pagebreak(to: "even", weak: true)
  #[] <new-chapter>
  #pagebreak(to: "odd", weak: true)

  #let chapter-number = locate(loc => counter(heading).at(loc).first())
  #v(2em)
  #h(1fr) #upper[#it.supplement] #chapter-number
  #v(1em)

  // the set rule for the text also applies to the lines
  #set text(size: 24pt)
  #line(length: 100%)
  #text(it.body)
  #line(length: 100%)
  #v(1em)
]

#let styledOutline(
  title,
  target: heading.where(outlined: true),
  depth: 3,
  indent: auto,
  fill: repeat([.]),
  outlined: false
  ) = [
  // override the show-rule for the chapter heading
  #show heading: it => {
    set text(size: 24pt)
    text(it.body)
    line(length: 100%)
    v(1em)
  }

  #pagebreak(weak: true)
  // use a dummy heading to allow the "outlined" parameter to be applied to the outline
  #heading(depth: 1, numbering: none, outlined: outlined)[#title] <outline>
  #show heading: none // completely hide the actual title of the outline
  #outline(title: "", target: target, depth: depth, indent: indent, fill: fill)
]

#let thesis(
  title: "",
  author: "",
  type: "",
  lang: "",
  institute: "",
  birthplace: "",
  date: datetime.today(),
  body,
) = {
  set document(title: title, author: author, date: date)
  set page(
    margin: (left: 30mm, right: 30mm, top: 40mm, bottom: 40mm),
    numbering: "1",
    number-align: center,
    header: page-header,
    footer: page-footer,
  )
  set heading(numbering: "1.1", supplement: heading-supplement)
  show heading.where(level: 1): it => chapter-heading(it)

  set par(justify: true, first-line-indent: 1em)
  let body-font = "New Computer Modern"
  set text(font: body-font, size: 12pt, lang: lang)

  titlepage(title, author, type, lang, institute, birthplace, date)

  // apply some styles specific to the front matter
  {
    set page(numbering: "i")
    counter(page).update(1)
    styledOutline("Contents")
  }

  counter(page).update(1)
  body

  styledOutline("List of Figures", target: figure.where(kind: figure), outlined: true)
  styledOutline("List of Tables", target: figure.where(kind: table), outlined: true)
}