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

  let chapter = chapters.last()
  let chapter_number = counter(selector(heading.where(depth: 1))).display()
  return chapter.supplement + " " + chapter_number + h(0.7em) + chapter.body
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