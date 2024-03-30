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
  let chapter_heading_on_page = query(heading.where(level: 1), here()).find(h => h.location().page() == here().page()) != none
  if chapter_heading_on_page {
    return
  }

  set text(10pt)
  let _underline = move(dx: 0pt, dy: -0.7em, line(length: 100%))

  let chapters = query(selector(heading.where(depth: 1)).before(here()))
  if chapters.len() == 0 {
    return "no chapters yet..." + _underline
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
  )
  set heading(numbering: "1.1", supplement: heading_supplement)
  show heading.where(level: 1): it => {
    let chapter_number = locate(loc => counter(heading).at(loc).first())
    pagebreak(to: "odd")
    v(2em)
    h(1fr) + "CHAPTER " + chapter_number
    v(1em)

    set text(size: 24pt)
    line(length: 100%)
    text(it.body)
    line(length: 100%)
    v(1em)
  }

  let body-font = "New Computer Modern"
  set text(font: body-font, size: 12pt, lang: lang)

  titlepage(title, author, type, lang, institute, birthplace, date)

  body
}