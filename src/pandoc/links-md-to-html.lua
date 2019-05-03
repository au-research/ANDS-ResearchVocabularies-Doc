-- Map link addresses from .md to .html.
-- Based on an answer at
-- https://stackoverflow.com/questions/40993488/convert-markdown-links-to-html-with-pandoc/41005658
-- Modified to match ".md" only at the end of the link address.

function Link(el)
  el.target = string.gsub(el.target, "%.md$", ".html")
  return el
end
