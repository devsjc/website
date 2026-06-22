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
  set raw(theme: none)

  title()
  
  if sub != none {
    heading(level: 4)[ #sub \/\/ \ ]
  }
  
  let author-string = if type(author) == str { 
    author 
  } else if type(author) == array { 
    author.join(", ") 
  } else { 
    "Anonymous" 
  }
  
  heading(level: 3)[#date • By #author-string]
  
  body
}
