#import "@preview/headcount:0.1.0": dependent-numbering, normalize-length, reset-counter
#import "titlepage.typ": titlepage


// A floating figure that is correctly targeted by references
//
// If the figure placement is set to `auto`, `top` or `bottom`, references to
// the figures will point to the "original" location of the figures. In most
// cases this will even be on a different page since the figures have "floated"
// to their optimal position.
//
// The workaround here wraps the figures in a `place()` element that takes over
// the "floating". The figure itself can use the placement `none` that results
// in the correct pointing by the references. This was suggested in the issue
// https://github.com/typst/typst/issues/4359#issuecomment-2743931708
//
// If the figure placement is not set to `none`, the references will point to
// the caption instead of the figure. While this is better than the original
// case, it still feels odd while navigating through the document.
//
// - body (content): The figure body
// - caption (content): The figure caption
// - label (label): The figure label
// - placement (alignment): The placement of the figure (applied to `place()`)
#let floating-figure(
  body,
  caption: [],
  label: none,
  placement: top,
) = place(placement, float: true, [
  #figure(
    body,
    caption: caption,
  ) #label
])


// Find the references to a label and create a list of links
//
// - label (label): The label to query
// -> content
#let find-refs(label) = {
  query(ref.where(target: label))
    .map(ref => {
      return link(ref.location())[
        [#counter(page).at(ref.location()).at(0)]
      ]
    })
    .join([])
}

// Place a label and references
//
// - label (label): The label
// - refs (content, none): The references to the `label`
// -> content
#let place-label-and-refs(label, refs, ..args) = place(..args)[
  #set text(blue, weight: 400, size: 10pt)
  <#str(label)>
  refs: #if refs != none { refs } else { "none" }
]

// Show rule to display the label and references
//
// This function can be used as a show rule for anything that can
// have a label.
// ```
// show math.equation.where(block: true): show-label-and-refs
// ```
//
// Wrapping the entire figure in a block to place the label and refs will break
// the positioning of the figures. Only the figure caption is therefore wrapped
// in the block.
#let show-label-and-refs(it) = {
  if not it.has("label") { return it }

  let label-and-refs = place-label-and-refs(it.label, find-refs(it.label), top + left, dy: -0.9em)
  if it.func() == heading or it.func() == math.equation {
    block({ it + label-and-refs })
  } else if it.func() == figure {
    show figure.caption: caption => {
      block(width: 100%, { caption + highlight(fill: white, label-and-refs) })
    }
    it
  } else {
    it
  }
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
  let is-chapter-start = query(heading.where(level: 1)).any(it => it.location().page() == page)
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
  let has-content = state("content.pages", (0,)).get().contains(here().page())
  if has-content {
    align(
      if calc.even(here().page()) { left } else { right },
      counter(page).display(here().page-numbering()),
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

  // only wrap the actual title in the block to correctly place the label and refs
  block({
    if debug and it.has("label") {
      place-label-and-refs(it.label, find-refs(it.label), top, dy: -0.9em)
    }
    line(length: 100%) + v(0.8em) + it.body + line(length: 100%) + v(1em)
  })
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
  fill: repeat[.],
) = [
  #if title == auto { title = outline-title("table-of-contents") }
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
  #if title == auto { title = outline-title("list-of-figures") }
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
  #if title == auto { title = outline-title("list-of-tables") }
  #show heading: outline-heading
  #heading(depth: 1, numbering: none, outlined: true)[#title] <outline>
  #outline(title: none, target: target)
]


// Evaluate the dependent numbering from the headcount package
//
// The function `dependent-numbering()` is meant to be passed
// to the `numbering` field in a figure set rule. Since I have
// to manually evaluate the numbering in captions and outline
// entries, the function must allow evaluation for a certain
// figure kind at a specific location.
//
// - style (str): Figure numbering style
// - levels (int): The number of heading levels to inherit
// - kind (figure): The figure type, e.g. `image`, `table`, etc...
// - loc (location): The location of the figure
// -> (str)
#let get-dependent-numbering(style, levels, kind, loc) = numbering(
  style,
  ..normalize-length(counter(heading).at(loc), levels),
  ..counter(figure.where(kind: kind)).at(loc),
)

// Split a figure caption into a title and the rest
//
// The caption of a figure is usually just a block of content.
// In the context of a thesis the caption can get quite long
// and it would be great if the actual "title" of the figure
// could be inferred from the caption. The title can then be
// highlighted by using a bold font. And the title can also be
// used in the table of figures where using the entire caption
// would just take an insane amount of space.
//
// The approach with this function is to infer the title from
// the caption body based on a specific separator. The easiest
// choice here is to use the full stop/period. A colon could
// also be useful in some cases.
// The separator is not included with either the title or the
// rest since the outline should not show the separator. In
// the regular figure caption, the separator is just appended
// to the title.
//
// Certain functions can be "protected" from splitting. The
// best example is `math.equation` which might have decimal
// numbers with a period as the separator. Splitting the
// equation at the decimal separator would just feel wrong.
//
// An alternative approach is to define a short caption and a
// long caption. The short caption will then be used for the
// outline, and the long caption is used for the figure. This
// is suggested in the Typst Examples Book:
// https://sitandr.github.io/typst-examples-book/book/snippets/chapters/outlines.html#long-and-short-captions-for-the-outline
//
// - body (content): The caption
// - separator (str): The separator to infer the title
// - protected (array): Functions to protect from splitting
// -> (dictionary):
//    - title (content)
//    - rest (content or none)
#let split-figure-caption(body, separator, protected: (math.equation,)) = {
  if "text" in body.fields() {
    // the actual separation is done here
    let position = body.text.position(separator)
    if position != none {
      return (title: text(body.text.slice(0, position)), rest: text(body.text.slice(position + 1)))
    } else {
      return (title: body, rest: none)
    }
  } else if "child" in body.fields() {
    // this takes care of `styled()` functions such as `text(red)`
    let func = body.func()
    if func in protected { return (title: body, rest: none) }
    let args = body.styles
    let (title, rest) = split-figure-caption(body.child, separator)
    if rest != none {
      return (title: func(title, args), rest: func(rest, args))
    } else {
      return (title: body, rest: none)
    }
    return (title: func(title, args), rest: if rest == none { none } else { func(rest, args) })
  } else if "body" in body.fields() {
    // this takes care of simple functions such as `emph()`
    let func = body.func()
    if func in protected { return (title: body, rest: none) }
    let (title, rest) = split-figure-caption(body.body, separator)
    if rest != none {
      return (title: func(title), rest: func(rest))
    } else {
      return (title: body, rest: none)
    }
  } else if "children" in body.fields() {
    // this takes care of content sequences
    let titles = ()
    let children = body.children
    if children.at(0, default: none) == [ ] { _ = children.remove(0, default: none) }
    for i in range(children.len()) {
      let (title, rest) = split-figure-caption(children.at(i), separator)
      titles.push(title)
      if rest != none {
        return (
          title: titles.join([]),
          rest: ((rest,) + children.slice(i + 1)).join([]),
        )
      }
    }

    // if the rest was none in all of the children
    return (title: titles.join([]), rest: none)
  } else {
    return (title: body, rest: none)
  }
}

// Highlight the title of a figure caption
//
// The supplement, numbering and the title will be bold.
// The "rest" of the caption is just appended without any
// changes.
// The `dependent-numbering` from the headcount package is
// implemented by the function `get-dependent-numbering()`.
//
// - style (str): Figure numbering style
// - levels (int): The number of heading levels to inherit
// - separator (str): The separator to infer the title
// -> (content)
#let show-figure-caption(style, levels, separator) = it => context {
  let (title, rest) = split-figure-caption(it.body, separator)

  {
    set text(weight: 600)
    show math.equation: math.bold
    it.supplement + [ ]

    // the dependent-numbering has to be recreated manually here...
    // use it.kind to automatically handle the different figure types
    get-dependent-numbering(style, levels, it.kind, here())
    it.separator
    title + separator
  }

  rest
}

// Use the title of a figure caption as the outline entry
//
// The `dependent-numbering` from the headcount package is
// implemented by the function `get-dependent-numbering()`.
//
// The hacks with the zero-width box, the Unicode word joiner
// `sym.wj` and the nobreak space were suggested here:
// https://forum.typst.app/t/how-to-fix-the-bug-for-outline-entries-with-long-titles/707/3
// https://forum.typst.app/t/how-can-i-right-align-the-qed-symbol-after-a-proof/948/3
//
// The issue with the line wrapping of long titles was fixed in v0.13 when using
// `it.inner()`. Since we are however customizing the inner content here, we need
// to use the old solution to get all the spacings right.
//
// - style (str): Figure numbering style
// - levels (int): The number of heading levels to inherit
// - separator (str): The separator to infer the title
// - repeat-gap (length): The gap for the repeat between body and page number
// - repeat-body (content or str): The body for the repeat
// - page-width (relative or auto): The width of the box for the page number
// - page-align (alignment): The alignment of the page number
// -> (content)
#let show-figure-outline-entry(
  style,
  levels,
  separator,
  repeat-gap: 0.25em,
  repeat-body: [.],
  page-width: 1.5em,
  page-align: right,
) = it => context {
  let fig = it.element
  let number = get-dependent-numbering(style, levels, fig.kind, fig.location())
  let body = {
    split-figure-caption(it.body(), separator).title + [ ]
    box(width: 0pt)
    box(width: 1fr, repeat(gap: repeat-gap, repeat-body))
    sym.wj + sym.space.nobreak
    box(width: page-width, align(page-align, it.page()))
  }
  link(fig.location(), it.indented(number, body))
}


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

  let heading-numbering-style = "1.1"
  let figure-numbering-style = "1.1"
  let figure-numbering-levels = 1
  let figure-caption-separator = "."
  let equation-numbering-style = "(1.1)"
  let equation-numbering-levels = 1

  // Call these show rules first to allow them to be overridden by special
  // functions that manually display an item, such as `chapter-heading()`.
  show heading: if debug { show-label-and-refs } else { it => it }
  show figure: if debug { show-label-and-refs } else { it => it }
  show math.equation.where(block: true): if debug { show-label-and-refs } else { it => it }

  // Set and show rules for the customized chapter and section headings
  set heading(numbering: heading-numbering-style, supplement: heading-supplement)
  show heading.where(level: 1): set text(size: 24pt)
  show heading.where(level: 1): chapter-heading(debug)

  // Set and show rules for the headcount package
  set figure(numbering: dependent-numbering(figure-numbering-style, levels: figure-numbering-levels))
  set math.equation(numbering: dependent-numbering(equation-numbering-style, levels: equation-numbering-levels))
  show heading: reset-counter(counter(figure.where(kind: image)))
  show heading: reset-counter(counter(figure.where(kind: table)))
  show heading: reset-counter(counter(figure.where(kind: raw)))
  show heading: reset-counter(counter(math.equation))

  // Modify the captions and outline entries of figures
  show figure.caption: show-figure-caption(figure-numbering-style, figure-numbering-levels, figure-caption-separator)
  show outline
    .where(target: figure.where(kind: image))
    .or(outline.where(target: figure.where(kind: table)).or(outline.where(target: figure.where(kind: raw)))): it => {
    show outline.entry: show-figure-outline-entry(
      figure-numbering-style,
      figure-numbering-levels,
      figure-caption-separator,
    )
    it
  }

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
