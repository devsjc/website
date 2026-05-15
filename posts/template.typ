#let article(
  head: none,
  sub: none,
  author: (),
  description: none,
  keywords: (),
  date: none,
  body
) = {
  set document(
    title: head,
    author: author,
    description: description,
    keywords: keywords,
  )

  title()
  
  if sub != none {
    text(style: "italic")[ #sub \/\/ \ ]
  }
  
  let author-string = if type(author) == str { 
    author 
  } else if type(author) == array { 
    author.join(", ") 
  } else { 
    "Anonymous" 
  }
  
  heading(level: 3)[#date • By #author-string]
  line(length: 100%, stroke: 0.5pt)
  
  body
}
