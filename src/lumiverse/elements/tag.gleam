import gleam/bool
import gleam/list
import gleam/order
import gleam/string
import lumiverse/api/series
import lustre/attribute
import lustre/element
import lustre/element/html

pub const special = ["doujinshi", "uncensored", "special-test-tag"]

pub const explicit = [
  "hentai", "sexual violence", "gore", "erotica", "borderline h", "boobjob",
  "bukakke", "footjob", "defloration", "handjob", "masturbation", "intercourse",
  "vaginal", "anal", "oral", "cunnilingus", "paizuri", "rape", "creampie",
  "threesome", "group sex", "tentacle", "mind control", "bondage", "bdsm",
  "exhibitionism", "gangbang", "bestiality", "sexual content", "partial nudity",
  "explicit-test-tag", "explicit-2-test-tag",
]

pub const beware = [
  "suggestive", "ecchi", "fan service", "nudity", "innuendo", "violence",
  "alcohol", "drugs", "profanity", "torture", "netorare", "ntr", "incest",
  "shotacon", "lolicon", "femdom", "maledom", "bullying", "beware-test-tag",
]

pub const lgbtq = [
  "yuri",
  "yaoi",
  "boys love",
  "girls love",
  "shounen ai",
  "shoujo ai",
  "shounen-ai",
  "shoujo-ai",
  "gay",
  "lesbian",
  "bisexual",
  "transgender",
  "trans",
  "queer",
  "gender bender",
  "crossdressing",
  "lgbt",
  "lgbtq",
  "lgbtqia",
  "lgbtq+",
  "rainbow",
]

pub const tag_appearance = "font-[Poppins,sans-serif] text-xs font-medium hover:brightness-110 cursor-pointer"

pub fn list(tags: List(series.Tag)) {
  list_with_function(tags, fn(_t) { [] })
}

pub fn list_with_function(
  tags: List(series.Tag),
  f: fn(series.Tag) -> List(attribute.Attribute(a)),
) {
  html.div(
    [attribute.class("inline-flex flex-wrap gap-2")],
    list.map(sort(tags), fn(t) { single(t, f(t)) }),
  )
}

pub fn single(tag: series.Tag, attrs: List(attribute.Attribute(a))) {
  case tag.title |> string.lowercase {
    "staff pick" ->
      element(
        [attribute.class("capitalize bg-violet-500 text-white gap-1"), ..attrs],
        [
          html.i([attribute.class("ph-fill ph-star")], []),
          element.text(tag.title),
        ],
      )
    _ ->
      simple(tag.title |> string.capitalise, [
        attribute.class("capitalize"),
        color(tag.title),
        ..attrs
      ])
  }
}

pub fn simple(tag: String, attrs: List(attribute.Attribute(a))) {
  element(attrs, [element.text(tag)])
}

pub fn element(
  attrs: List(attribute.Attribute(a)),
  elems: List(element.Element(a)),
) {
  html.div(
    [
      attribute.class(tag_appearance),
      attribute.class(
        "flex relative group h-fit self-center items-center justify-center rounded-full py-0.5 px-2 select-none",
      ),
      ..attrs
    ],
    elems,
  )
}

pub fn color(tag: String) {
  {
    use <- bool.guard(tag_in_list(tag, special), "bg-sky-950/60 text-sky-400")
    use <- bool.guard(tag_in_list(tag, explicit), "bg-red-950/60 text-red-400")
    use <- bool.guard(tag_in_list(tag, beware), "bg-pink-950/60 text-pink-400")
    use <- bool.guard(
      tag_in_list(tag, lgbtq),
      "[background:linear-gradient(to_right,#ef4444cc,#f97316cc,#eab308cc,#22c55ecc,#3b82f6cc,#8b5cf6cc)] text-white",
    )
    "bg-zinc-800 text-zinc-400"
  }
  |> attribute.class
}

fn tag_in_list(tag: String, lst: List(String)) -> Bool {
  let t = string.lowercase(tag)
  list.any(lst, fn(k) {
    t == k
    || string.starts_with(t, k <> " ")
    || string.ends_with(t, " " <> k)
    || string.contains(t, " " <> k <> " ")
  })
}

pub fn sort(tags: List(series.Tag)) {
  list.sort(tags, tag_compare)
}

fn tag_compare(a: series.Tag, b: series.Tag) -> order.Order {
  case compare_in_list(a.title, b.title, ["staff pick"]) {
    order.Eq ->
      case compare_in_list(a.title, b.title, special) {
        order.Eq ->
          case compare_in_list(a.title, b.title, explicit) {
            order.Eq ->
              case compare_in_list(a.title, b.title, beware) {
                order.Eq ->
                  case compare_in_list(a.title, b.title, lgbtq) {
                    order.Eq -> string.compare(a.title, b.title)
                    res -> res
                  }
                res -> res
              }
            res -> res
          }
        res -> res
      }
    res -> res
  }
}

fn compare_in_list(a: String, b: String, lst: List(String)) -> order.Order {
  let a_in_list = tag_in_list(a, lst)
  let b_in_list = tag_in_list(b, lst)

  case a_in_list, b_in_list {
    True, False -> order.Lt
    False, True -> order.Gt
    _, _ -> order.Eq
  }
}
