import gleam/bool
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

pub const explicit = ["hentai", "explicit-test-tag"]

pub const beware = ["suggestive", "beware-test-tag"]

pub fn single(tag: String) {
  html.div(
    [
      attribute.class(
        "font-[Poppins,sans-serif] font-extrabold text-xs flex relative group h-fit self-center items-center justify-center rounded py-0.5 px-1",
      ),
      attribute.class(evaluate_tag_color(tag)),
    ],
    [html.span([], [element.text(tag)])],
  )
}

fn evaluate_tag_color(tag: String) {
  use <- bool.guard(
    list.contains(explicit, string.lowercase(tag)),
    "bg-red-500",
  )
  use <- bool.guard(
    list.contains(beware, string.lowercase(tag)),
    "bg-amber-500",
  )
  "bg-zinc-700"
}
