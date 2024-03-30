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
  set text(10pt)
  let chapters = query(selector(heading.where(depth: 1)).before(here()))

  if chapters.len() == 0 {
    return "no chapters yet..."
  }

  // the counter returns an array...
  let (page_count, ) = counter(page).get()
  if (calc.rem(page_count, 2) == 0) {
    let chapter = chapters.last()
    // explicitely select the chapter counter by specifying the depth
    let chapter_number = counter(selector(heading.where(depth: 1))).display()
    return chapter.supplement + " " + chapter_number + h(0.7em) + chapter.body
  }

  // get all headings of depth 1 and depth 2 to check if the most recent heading is a "section"
  let headings = query(selector(heading.where(depth: 1).or(heading.where(depth: 2))).before(here()))
  if (headings.last().depth == 1) {
    return "no sections yet..."
  }

  let section = headings.last()
  // using the selector(heading.where(depth: 2)) will just count the sections on their own
  // instead of the sections numbers 1.1, 1.2, 2.1 the output will be 0.1, 0.2, 0.3
  // since the most recent heading is a section, it is fine to directly use the heading counter
  let section_number = counter(heading).display()
  return section.supplement + " " + section_number + h(0.7em) + section.body
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

  let body-font = "New Computer Modern"
  set text(font: body-font, size: 12pt, lang: lang)

  titlepage(title, author, type, lang, institute, birthplace, date)

  body
}