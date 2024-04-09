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

// Modified page footer
//
// This is supposed to be passed to the set rule of the page 
// ```
// set page(footer: footer-header)
// ```
// 
// The footer will only be hidden on empty pages that are inserted to ensure
// that the next chapter starts on an odd page. There is always an offset of 1
// between the location of the <empty-page> label and the location of the
// actual empty page. The query for <empty-page> labels can therefore just
// look at the most recent label before the current page in the context.
// The label <empty-page> will be placed regardless of whether an empty page
// is actually added. It is therefore necessary to also check that the current
// page does NOT have a <new-chapter> label.
//
// The page numbers are aligned to the left/right on even/odd pages which is
// always the 'outside' alignment when the document is printed.
#let page-footer = context {
  let empty-page-labels = query(selector(<empty-page>).before(here()))
  if empty-page-labels.len() > 0 {
    let empty-page = empty-page-labels.last().location().page()
    let new-chapter = query(selector(<new-chapter>).before(here())).last().location().page()
    if (new-chapter != here().page()) and (empty-page + 1 == here().page()) {
      return none 
    }
  }

  let page-display = counter(page).display(here().page-numbering())
  if calc.even(here().page()) { page-display } else { h(1fr) + page-display }
}

// Custom chapter heading
// 
// This function is supposed to be used as a show rule for (level 1) headings
// ```
// show heading.where(level: 1): it => chapter-heading(it)
// ```
//
// To ensure that a new chapter always starts on a (new) odd page, two weak
// pagebreaks are inserted. Two pagebreaks are required to position the labels
// <empty-page> and <new-chapter> that are required for the `page-header` and
// the `page-footer`. Without the labels, it would be perfectly fine to just
// use a single (non-weak) pagebreak to the next odd page.
// If the current page is even, the first pagebreak will not do anything. There
// will be no empty page. Even though the labels are supposed to be on the same
// page, the page of the <empty-page> label will still be one less than the
// page of the <new-chapter> label. This effectively puts them on the same page
// since the <empty-page> labels are always evaluated on the next page.
// If the current page is odd, both pagebreaks will start a new page and there
// will be a difference of two between the pages of the label pair. The page
// in between the two labels is the empty one and can be treated accordingly.
#let chapter-heading(it) = [
  #let (page-count, ) = counter(page).get()
  #[] <empty-page>
  #pagebreak(to: "even", weak: true)
  #[] <new-chapter>
  #pagebreak(to: "odd", weak: true)

  #let chapter-number = locate(loc => counter(heading).at(loc).first())
  #v(2em)
  #h(1fr) #text(size: 0.7 * text.size)[#upper[#it.supplement]] #chapter-number
  #v(1em)

  // the set rule for the text also applies to the lines
  #line(length: 100%)
  #text(it.body)
  #line(length: 100%)
  #v(1em)
]

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
// - target (label, selector, location, function): Elements to include in the list of figures, defaults to `figure.where(kind: figure)`
// -> content
#let list-of-figures(
  title: auto,
  target: figure.where(kind: figure),
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
  show heading.where(level: 1): set text(size: 24pt)
  show heading.where(level: 1): chapter-heading

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