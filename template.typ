#import "titlepage.typ": titlepage

#let heading_supplement(it) = {
  if it.depth == 1 {
    return [Chapter]
  } else if (it.depth == 2) {
    return [Section]
  } else if (it.depth == 3) {
    return [Subsection]
  }
}

#let page_header = context {
  // query for all <empty-page> and <new-chapter> label locations
  let empty_pages = query(selector(<empty-page>)).map(label => label.location().page())
  let new_chapters = query(selector(<new-chapter>)).map(label => label.location().page())
  if new_chapters.len() > 0 {
    if new_chapters.contains(here().page()) {
      return
    }

    // get the index of the next <new-chapter> label
    let new_chapter_index = new_chapters.position(page => page > here().page())
    if new_chapter_index != none {
      let empty_page = empty_pages.at(new_chapter_index)
      if empty_page < here().page() {
        return
      }
    }
  }

  // query for all <outline> label locations
  // the (possible) further pages of outline chapters are handled later
  let outlines = query(selector(<outline>)).map(label => label.location().page())
  if outlines.contains(here().page()) {
    return
  }

  set text(10pt)
  let _underline = move(dx: 0pt, dy: -0.7em, line(length: 100%))

  let chapters = query(selector(heading.where(depth: 1)).before(here()))
  if chapters.len() == 0 {
    return "no chapters yet..." + _underline
  } else {
    // remove the heading on further pages of outline chapters
    if chapters.last().numbering == none {
      return
    }
  }

  // the counter returns an array...
  let (page_count, ) = counter(page).get()
  if calc.even(page_count) {
    let chapter = chapters.last()
    // explicitely select the chapter counter by specifying the depth
    let chapter_number = counter(selector(heading.where(depth: 1))).display()
    return chapter.supplement + " " + chapter_number + h(0.7em) + chapter.body + _underline
  }

  // select all chapters (depth = 1) and sections (depth = 2)
  // compared to selecting chapters and sections separately, this will conserve the order of the headings
  // just using selector(heading) would also include any (sub)subsections with depth > 2
  let chapter_section_selector = selector(heading.where(depth: 1).or(heading.where(depth: 2)))

  let headings = query(chapter_section_selector.before(here()))
  if (headings.last().depth == 1) {
    return h(1fr) + "no sections yet..." + _underline
  }

  let section = headings.last()
  // using the selector(heading.where(depth: 2)) will just count the sections on their own
  // instead of the sections numbers 1.1, 1.2, 2.1 the output will be 0.1, 0.2, 0.3
  // the chapter_section_selector will ensure that the correct section number is used
  let section_number = counter(chapter_section_selector).display()
  return h(1fr) + section.supplement + " " + section_number + h(0.7em) + section.body + _underline
}

#let page_footer = context {
  // compared to the header, the footer is only supposed to be omitted on empty pages
  // the pages with the <new-chapter> label therefore have to be conserved 
  //
  // since the page breaks in chapter_heading() are inserted after the <empty-page> label,
  // the selector has to look "before" the current page to find the relevant label
  let empty_page_labels = query(selector(<empty-page>).before(here()))
  if empty_page_labels.len() > 0 {
    let empty_page = empty_page_labels.last().location().page()
    // look back at the most recent <new-chapter> label
    let new_chapter = query(selector(<new-chapter>).before(here())).last().location().page()
    // check that there is no <new-chapter> label on the current page
    if (new_chapter != here().page()) and (empty_page + 1 == here().page()) {
      return
    }
  }

  // left/right align the page number on even/odd pages
  let page_display = counter(page).display(here().page-numbering())
  return if calc.even(here().page()) { page_display } else { h(1fr) + page_display }
}

// labels can only be used in markup mode
#let chapter_heading(it) = [
  #let (page_count, ) = counter(page).get()
  #[] <empty-page>
  #pagebreak(to: "even", weak: true)
  #[] <new-chapter>
  #pagebreak(to: "odd", weak: true)

  #let chapter_number = locate(loc => counter(heading).at(loc).first())
  #v(2em)
  #h(1fr) CHAPTER #chapter_number
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
    header: page_header,
    footer: page_footer,
  )
  set heading(numbering: "1.1", supplement: heading_supplement)
  show heading.where(level: 1): it => chapter_heading(it)

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