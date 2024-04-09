#import "template.typ": thesis, find-labels

#show: thesis.with(
  title: "Blazingly Fast Thesis Typesetting",
  author: "Your Name",
  type: "phd",
  lang: "en",
  institute: "Very Scientific Institute",
  birthplace: "Some City",
  date: datetime.today(),
)
