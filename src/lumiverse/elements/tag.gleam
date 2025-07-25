import gleam/bool
import gleam/list
import gleam/string
import lustre/event

import lustre/attribute
import lustre/element
import lustre/element/html

import lumiverse/layout
import tag_criteria

pub fn list(tags: List(String)) -> element.Element(layout.Msg) {
  html.div(
    [attribute.class("flex flex-wrap gap-2")],
    list.map(tags, fn(t: String) -> element.Element(layout.Msg) { single(t) }),
  )
}

pub fn single(tag: String) -> element.Element(layout.Msg) {
  html.div(
    [
      attribute.class(
        "flex relative group h-fit self-center items-center justify-center rounded py-0.5 px-1 "
        <> {
          let is_content_type =
            list.contains(tag_criteria.content_type, string.lowercase(tag))
          let is_special =
            list.contains(tag_criteria.special, string.lowercase(tag))
          let is_explicit =
            list.contains(tag_criteria.explicit, string.lowercase(tag))
          let is_suggestive =
            list.contains(tag_criteria.beware, string.lowercase(tag))

          use <- bool.guard(when: is_content_type, return: "bg-sky-500")
          use <- bool.guard(when: is_special, return: "bg-emerald-500")
          use <- bool.guard(when: is_explicit, return: "bg-red-500")
          use <- bool.guard(when: is_suggestive, return: "bg-amber-500")
          "bg-zinc-800"
        },
      ),
    ],
    [
      html.span(
        [
          attribute.class("group-hover:opacity-0"),
          event.on_click(layout.TagClicked(cross: False)),
        ],
        [element.text(tag)],
      ),
      html.span(
        [
          attribute.class("icon-cross absolute hidden group-hover:block"),
          event.on_click(layout.TagClicked(cross: True)),
        ],
        [],
      ),
    ],
  )
}

pub fn single_custom(tag: String, color: String) -> element.Element(layout.Msg) {
  html.div(
    [attribute.class("h-fit self-center rounded py-0.5 px-1 " <> color)],
    [html.span([], [element.text(tag)])],
  )
}

pub fn list_title(
  title: String,
  badges: List(String),
) -> element.Element(layout.Msg) {
  html.div([], [html.h3([], [element.text(title)]), list(badges)])
}

pub fn badge(name: String) -> element.Element(layout.Msg) {
  html.span([attribute.href("/tags/" <> name)], [element.text(name)])
}
