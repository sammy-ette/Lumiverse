import gleam/bool
import gleam/int
import gleam/list
import gleam/order
import gleam/string
import lumiverse/api/series
import lustre/attribute
import lustre/element
import lustre/element/html

pub const special = ["doujinshi", "uncensored", "manhwa", "special-test-tag"]

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

pub const tag_appearance = "font-[Poppins,sans-serif] text-xs font-medium cursor-pointer"

pub type Classification {
  StaffPick
  Special
  Explicit
  Beware
  Lgbtq
  Normal
}

pub fn classify(title: String) -> Classification {
  let t = string.lowercase(title)
  use <- bool.guard(t == "staff pick", StaffPick)
  use <- bool.guard(tag_in_list(t, special), Special)
  use <- bool.guard(tag_in_list(t, explicit), Explicit)
  use <- bool.guard(tag_in_list(t, beware), Beware)
  use <- bool.guard(tag_in_list(t, lgbtq), Lgbtq)
  Normal
}

fn classification_priority(c: Classification) -> Int {
  case c {
    StaffPick -> 0
    Special -> 1
    Explicit -> 2
    Beware -> 3
    Lgbtq -> 4
    Normal -> 5
  }
}

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
  case classify(tag.title) {
    StaffPick ->
      element([color(tag.title), ..attrs], [
        html.i([attribute.class("ph ph-[star--fill]")], []),
        element.text(tag.title),
      ])
    _ -> simple(tag.title |> string.capitalise, [color(tag.title), ..attrs])
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
        "flex relative group h-fit self-center items-center justify-center rounded-full py-0.5 px-2 select-none capitalize gap-1",
      ),
      ..attrs
    ],
    elems,
  )
}

pub fn included_style(title: String) -> attribute.Attribute(a) {
  case classify(title) {
    Normal -> attribute.class("bg-zinc-600 text-white")
    StaffPick -> attribute.class("bg-yellow-600 text-white brightness-110")
    Special -> attribute.class("bg-sky-800 text-sky-100 brightness-110")
    Explicit -> attribute.class("bg-red-800 text-red-100 brightness-110")
    Beware -> attribute.class("bg-pink-800 text-pink-100 brightness-110")
    Lgbtq ->
      attribute.class(
        "[background:linear-gradient(to_right,#ef4444,#f97316,#eab308,#22c55e,#3b82f6,#8b5cf6)] text-white brightness-110",
      )
  }
}

pub fn excluded_style(title: String) -> attribute.Attribute(a) {
  case classify(title) {
    Normal -> attribute.class("bg-transparent text-zinc-400")
    StaffPick -> attribute.class("bg-transparent text-yellow-400/70")
    Special -> attribute.class("bg-transparent text-sky-400/70")
    Explicit -> attribute.class("bg-transparent text-red-400/70")
    Beware -> attribute.class("bg-transparent text-pink-400/70")
    Lgbtq ->
      attribute.class(
        "text-white/60 [background:linear-gradient(#09090b,#09090b)_padding-box,linear-gradient(to_right,#ef4444aa,#f97316aa,#eab308aa,#22c55eaa,#3b82f6aa,#8b5cf6aa)_border-box]",
      )
  }
}

pub fn excluded_border(title: String) -> attribute.Attribute(a) {
  case classify(title) {
    Normal -> attribute.class("border-zinc-600")
    StaffPick -> attribute.class("border-yellow-500/60")
    Special -> attribute.class("border-sky-600/60")
    Explicit -> attribute.class("border-red-600/60")
    Beware -> attribute.class("border-pink-600/60")
    Lgbtq -> attribute.class("border-transparent")
  }
}

pub fn dot_color(title: String) -> String {
  case classify(title) {
    StaffPick -> "text-violet-400"
    Special -> "text-sky-400"
    Explicit -> "text-red-400"
    Beware -> "text-pink-400"
    Lgbtq -> "text-purple-400"
    Normal -> ""
  }
}

pub fn color(title: String) -> attribute.Attribute(a) {
  case classify(title) {
    StaffPick -> attribute.class("bg-transparent border text-amber-300")
    Special ->
      attribute.class("bg-sky-950/80 text-sky-400 border border-transparent")
    Explicit ->
      attribute.class("bg-red-950/80 text-red-400 border border-transparent")
    Beware ->
      attribute.class("bg-pink-950/80 text-pink-400 border border-transparent")
    Lgbtq ->
      attribute.class(
        "[background:linear-gradient(to_right,#ef4444cc,#f97316cc,#eab308cc,#22c55ecc,#3b82f6cc,#8b5cf6cc)] text-white border border-transparent",
      )
    Normal ->
      attribute.class("bg-zinc-800 text-zinc-400 border border-transparent")
  }
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
  list.sort(tags, compare)
}

pub fn sort_reverse(tags: List(series.Tag)) {
  list.sort(tags, compare |> order.reverse)
}

pub fn compare(a: series.Tag, b: series.Tag) -> order.Order {
  case
    int.compare(
      classification_priority(classify(a.title)),
      classification_priority(classify(b.title)),
    )
  {
    order.Eq -> string.compare(a.title, b.title)
    res -> res
  }
}
