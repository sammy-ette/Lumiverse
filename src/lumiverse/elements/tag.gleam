import gleam/bool
import gleam/list
import gleam/order
import gleam/string
import lumiverse/api/series
import lustre/attribute
import lustre/element
import lustre/element/html

pub const special = ["doujinshi", "uncensored"]

pub const explicit = [
  "hentai", "sexual violence", "gore", "adult", "erotica", "explicit-test-tag",
  "explicit-2-test-tag",
]

pub const beware = ["suggestive", "ecchi", "beware-test-tag"]

pub const tag_appearance = "font-[Poppins,sans-serif] uppercase font-semibold text-[0.7rem]"

pub fn list(tags: List(series.Tag)) {
  html.div(
    [attribute.class("inline-flex flex-wrap gap-2")],
    list.map(sort(tags), single),
  )
}

pub fn single(tag: series.Tag) {
  html.div(
    [
      attribute.class(tag_appearance),
      attribute.class(
        "flex relative group h-fit self-center items-center justify-center rounded py-0.5 px-1",
      ),
      color(tag.title),
    ],
    [html.span([], [element.text(tag.title)])],
  )
}

pub fn simple(tag: String, attrs: List(attribute.Attribute(a))) {
  html.div(
    [
      attribute.class(tag_appearance),
      attribute.class(
        "flex relative group h-fit self-center items-center justify-center rounded py-0.5 px-1",
      ),
      ..attrs
    ],
    [html.span([], [element.text(tag)])],
  )
}

pub fn color(tag: String) {
  {
    use <- bool.guard(
      list.contains(special, string.lowercase(tag)),
      "bg-sky-500",
    )

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
  |> attribute.class
}

fn sort(tags: List(series.Tag)) {
  list.sort(tags, tag_compare)
}

fn tag_compare(a: series.Tag, b: series.Tag) -> order.Order {
  case compare_in_list(a.title, b.title, special) {
    order.Eq ->
      case compare_in_list(a.title, b.title, explicit) {
        order.Eq ->
          case compare_in_list(a.title, b.title, beware) {
            order.Eq -> string.compare(a.title, b.title)
            res -> res
          }
        res -> res
      }
    res -> res
  }
}

fn compare_in_list(a: String, b: String, lst: List(String)) -> order.Order {
  let a_in_list = list.contains(lst, string.lowercase(a))
  let b_in_list = list.contains(lst, string.lowercase(b))

  case a_in_list, b_in_list {
    True, False -> order.Lt
    False, True -> order.Gt
    _, _ -> order.Eq
  }
}
