#import "@preview/headcount:0.1.0": dependent-numbering, reset-counter
#import "titlepage.typ": titlepage

// Find the references to a label and create a list of links
// 
// - label (label): The label to query
// -> content
#let find-refs(label) = {
  query(ref.where(target: label)).map(ref => {
    return link(ref.location())[
      [#counter(page).at(ref.location()).at(0)]
    ]
  }).join([])
}

// Place a label and references next to some content
// 
// - c (content): The actual content
// - label (label): The label belonging to (the parent of) `c`
// - refs (content, none): The references to (the parent of) `c`
// -> content
#let place-label-and-refs(c, label, refs) = block(width: 100%)[
    #c
    #place(top + left, dy: -0.9em)[
      #set text(blue, weight: 400, size: 10pt)
      <#str(label)>
      refs: #if refs != none { refs } else { "none" }
    ]
  ]

// Show rule to display the label and references
// 
// This function can be used as a show rule for anything that can
// have a label.
// ```
// show math.equation.where(block: true): show-label-and-refs
// ```
#let show-label-and-refs(it) = {
  if not it.has("label") { return it }
  place-label-and-refs(it, it.label, find-refs(it.label))
}


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

// Modified page header to display heading information
// 
// This is supposed to be passed to the set rule of the page 
// ```
// set page(header: page-header)
// ```
// 
// The credit for the idea behind the function goes to https://github.com/jhalmen.
// See https://github.com/typst/typst/discussions/3122#discussioncomment-11022031.
// 
// This function uses the state "content.switch" and a query of chapter starts
// to check whether the current page should have a header. "content.switch" is
// set to false in the function `chapter-heading()` on empty pages before the
// start of a new chapter.
// 
// On all pages that show a header, the content alternates between the current
// chapter name and the current section name. On even pages the chapter is
// displayed with a 'left' alignment and on odd pages the section is displayed
// with a 'right' alignment.
#let page-header = context {
  let page = here().page()
  let is-chapter-start = query(heading.where(level: 1))
    .any(it => it.location().page() == page)
  if not state("content.switch", false).get() and not is-chapter-start {
    return
  }

  state("content.pages").update(it => return it + (page,))
  if is-chapter-start { return }

  set text(10pt)
  let _underline = move(dx: 0pt, dy: -0.7em, line(length: 100%))

  if calc.even(page) {
    let chapter = query(heading.where(level: 1).before(here())).last()
    if chapter.numbering != none {
      align(left)[
        #chapter.supplement
        #numbering(chapter.numbering, ..counter(heading).at(chapter.location()))
        #h(0.7em)
        #chapter.body
      ]
    }
  } else {
    let section = query(heading.where(level: 2).before(here())).last()
    if section.numbering != none {
      align(right)[
        #section.supplement
        #numbering(section.numbering, ..counter(heading).at(section.location()))
        #h(0.7em)
        #section.body
      ]
    }
  }

  _underline
}

// Modified page footer
//
// This is supposed to be passed to the set rule of the page 
// ```
// set page(footer: footer-header)
// ```
// 
// The credit for the idea behind the function goes to https://github.com/jhalmen.
// See https://github.com/typst/typst/discussions/3122#discussioncomment-11022031.
// 
// This function uses the state "content.pages" to check if a page has any
// content, and should therefore have a page number
// 
// The page numbers are aligned to the left/right on even/odd pages which is
// always the 'outside' alignment when the document is printed.
#let page-footer = context {
  let has-content = state("content.pages", (0,)).get()
    .contains(here().page())
  if has-content {
    align(
      if calc.even(here().page()) { left } else { right },
      counter(page).display(here().page-numbering())
    )
  }
}

// Custom chapter heading
// 
// This function is supposed to be used as a show rule for (level 1) headings
// ```
// show heading.where(level: 1): chapter-heading(false) 
// ```
//
// The credit for the idea behind the function goes to https://github.com/jhalmen.
// See https://github.com/typst/typst/discussions/3122#discussioncomment-11022031.
// 
// The state "content.switch" will be set to false on empty pages inserted by
// a pagebreak to an odd page before a new chapter. After the pagebreak the
// state is set to true again. Chapter starts will be queried separately in
// the `page-header()`.
#let chapter-heading(debug) = it => {
  state("content.switch").update(false)
  pagebreak(weak: true, to: "odd")
  state("content.switch").update(true)

  if it.numbering != none {
    v(2em)
    align(right)[
      #text(size: 0.7 * text.size)[#upper(it.supplement) ]
      #numbering(it.numbering, ..counter(heading).at(it.location()))
    ]
    v(1em)
  }

  let body = line(length: 100%) + v(0.8em) + it.body + line(length: 100%) + v(1em)
  if debug and it.has("label") {
    place-label-and-refs(body, it.label, find-refs(it.label))
  } else {
    body
  }
}

// Style the outline title similar to the chapter title
// 
// This function is supposed to be used as a show rule for headings in the
// scopes where the outlines are used/defined
// ```
// show heading: outline-heading
// ```
//
// Compared to the chapter-heading this only creates a single weak pagebreak
// and only the actual heading title is displayed. The supplement is omitted
// since the outline headings are not numbered anyway, and the horizontal line
// above the title is not shown either.
#let outline-heading(it) = {
  pagebreak(weak: true)
  text(it.body)
  line(length: 100%)
  v(1em)
}

// Outline titles in Enlish and German
//
// The title for the table-of-contents is already built into Typst, even with
// multi-language support. Since the title is used directly in a heading, this
// default value for the outline cannot be used anymore.
// For the list of figures/tables there is no built-in title in any language.
//
// - outline-type (str): "table-of-contents", "list-of-figures" or "list-of-tables"
// -> content
#let outline-title(outline-type) = context {
  if outline-type == "table-of-contents" {
    if text.lang == "en" {
      [Table of Contents]
    } else if text.lang == "de" {
      [Inhaltsverzeichnis]
    }
  } else if outline-type == "list-of-figures" {
    if text.lang == "en" {
      [List of Figures]
    } else if text.lang == "de" {
      [Abbildungsverzeichnis]
    }
  } else if outline-type == "list-of-tables" {
    if text.lang == "en" {
      [List of Tables]
    } else if text.lang == "de" {
      [Tabellenverzeichnis]
    }
  } else {
    panic("Unknown outline-type '" + outline-type + "'")
  }
}

// Create the table of contents
//
// This is a convenience function that wraps the actual `outline()`. Instead
// of using the `title` parameter of the `outline()`, a heading (of depth 1) is
// used for the outline title. This is done to add the <outline> label to this
// page which is required to hide the page-header.
//
// - title (str, auto, none, content): Title, defaults to "Contents"/"Inhaltsverzeichnis"
// - target (label, selector, location, function): Elements to include in the table of contents, defaults to `heading.where(outlined: true)`
// - depth (int, none): Maximum depth to show in the table of contents, defaults to 3
// - indent (auto, none, bool, relative, function): Indent of the outline entries, defaults to auto
// - fill (content, none): Content to fill the space in the outline entries, defaults to [.]
// -> content
#let table-of-contents(
  title: auto,
  target: heading.where(outlined: true),
  depth: 3,
  indent: auto,
  fill: repeat[.]
) = [
  #if title == auto { title = outline-title("table-of-contents")}
  #show heading: outline-heading
  #heading(depth: 1, numbering: none, outlined: false)[#title] <outline>
  #outline(title: none, target: target, depth: depth, indent: indent, fill: fill)
]

// Create the list of figures
//
// This is a convenience function that wraps the actual `outline()`. Instead
// of using the `title` parameter of the `outline()`, a heading (of depth 1) is
// used for the outline title. This is done to add the <outline> label to this
// page which is required to hide the page-header. In addition, the parameter
// `outlined` of the heading is set to `true` to include the list of figures in
// the table of contents.
//
// - title (str, auto, none, content): Title, defaults to "List of Figures"/"Abbildungsverzeichnis"
// - target (label, selector, location, function): Elements to include in the list of figures, defaults to `figure.where(kind: image)`
// -> content
#let list-of-figures(
  title: auto,
  target: figure.where(kind: image),
) = [
  #if title == auto { title = outline-title("list-of-figures")}
  #show heading: outline-heading
  #heading(depth: 1, numbering: none, outlined: true)[#title] <outline>
  #outline(title: none, target: target)
]

// Create the list of tables
//
// This is a convenience function that wraps the actual `outline()`. Instead
// of using the `title` parameter of the `outline()`, a heading (of depth 1) is
// used for the outline title. This is done to add the <outline> label to this
// page which is required to hide the page-header. In addition, the parameter
// `outlined` of the heading is set to `true` to include the list of tables in
// the table of contents.
//
// - title (str, auto, none, content): Title, defaults to "List of Tables"/"Tabellenverzeichnis"
// - target (label, selector, location, function): Elements to include in the list of tables, defaults to `figure.where(kind: table)`
// -> content
#let list-of-tables(
  title: auto,
  target: figure.where(kind: table),
) = [
  #if title == auto { title = outline-title("list-of-tables")}
  #show heading: outline-heading
  #heading(depth: 1, numbering: none, outlined: true)[#title] <outline>
  #outline(title: none, target: target)
]


#let thesis(
  title: "",
  author: "",
  type: "",
  lang: "",
  institute: "",
  birthplace: "",
  date: datetime.today(),
  debug: true,
  body,
) = {
  set document(title: title, author: author, date: date)
  set page(
    margin: (left: 30mm, right: 30mm, top: 40mm, bottom: 40mm),
    numbering: "1",
    header: page-header,
    footer: page-footer,
  )

  // Call these show rules first to allow them to be overridden by special
  // functions that manually display an item, such as `chapter-heading()`.
  show heading: if debug { show-label-and-refs } else { it => it }
  show figure: if debug { show-label-and-refs } else { it => it }
  show math.equation.where(block: true): if debug { show-label-and-refs } else { it => it }

  // Set and show rules for the headcount package
  set figure(numbering: dependent-numbering("1.1", levels: 1))
  set math.equation(numbering: dependent-numbering("(1.1)", levels: 1))
  show heading: reset-counter(counter(figure.where(kind: image)))
  show heading: reset-counter(counter(figure.where(kind: table)))
  show heading: reset-counter(counter(figure.where(kind: raw)))
  show heading: reset-counter(counter(math.equation.where(block: true)))

  // Set and show rules for the customized chapter and section headings
  set heading(numbering: "1.1", supplement: heading-supplement)
  show heading.where(level: 1): set text(size: 24pt)
  show heading.where(level: 1): chapter-heading(debug)

  set par(justify: true, first-line-indent: 1em)
  let body-font = "New Computer Modern"
  set text(font: body-font, size: 12pt, lang: lang)

  titlepage(title, author, type, lang, institute, birthplace, date)

  // apply some styles specific to the front matter
  {
    set page(numbering: "i")
    counter(page).update(1)
    table-of-contents()
  }

  counter(page).update(1)
  body

  list-of-figures()
  list-of-tables()
}