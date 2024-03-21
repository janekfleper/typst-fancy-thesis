#let phd_text = (
  "Dissertation",
  "zur",
  "Erlangung des Doktorgrades (Dr. rer. nat.)",
  "der",
  "Mathematisch-Naturwissenschaftlichen Fakultät",
  "der",
  "Rheinischen Friedrich-Wilhelms-Universität Bonn",
).join("\n")

#let bachelor_master_text(type, institute) = {
  return (
    if type == "bachelor" [Bachelor] else [Master] + "arbeit in Physik angefertigt im",
    institute,
    "",
    "vorgelegt der",
    "Mathematisch-Naturwissenschaftlichen Fakultät",
    "der",
    "Rheinischen Friedrich-Wilhelms-Universität Bonn",
  ).join("\n")
}

#let phd_author(author, birthplace) = {
  return ("vorgelegt von", author, "aus", birthplace).join("\n")
}

#let bachelor_master_author(author) = {
  return author
}

#let phd_titlepage(author, birthplace, date) = {
  v(10em)
  text(phd_text)
  v(6em)
  text(phd_author(author, birthplace))
  place(bottom + center, text("Bonn " + date.display("[year]")))
}

#let bachelor_master_titlepage(author, institute, date) = {
  v(1em)
  text(bachelor_master_author(author))
  v(8em)
  text(bachelor_master_text(type, institute))
  v(6em)

  place(bottom + center, {
    // the name of the month in German is currently not supported yet
    // see https://github.com/typst/typst/issues/1537
    set text(lang: "de")
    date.display("[month repr:long] [year]")
  })
}

#let titlepage(title, author, type, lang, institute, birthplace, date) = {
  set page(numbering: none)
  set align(center)

  text(2em, weight: 700, title)

  if type in ("bachelor", "master") {
    bachelor_master_titlepage(author, institute, date)
  } else if type == "phd" {
    phd_titlepage(author, birthplace, date)
  }
}
