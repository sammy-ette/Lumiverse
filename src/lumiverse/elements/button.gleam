import lustre/attribute
import lustre/element
import lustre/element/html

fn render(
  children: List(element.Element(msg)),
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  html.button(
    [
      attribute.class(
        "outline-none transition-all duration-200 active:not-disabled:scale-[95%] rounded-lg text-sm disabled:opacity-40 disabled:cursor-not-allowed",
      ),
      ..attrs
    ],
    children,
  )
}

pub fn button(
  label: String,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  render([element.text(label)], attrs)
}

pub fn icon(
  icon_class: String,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  render(
    [
      html.i(
        [attribute.class("leading-none text-2xl"), attribute.class(icon_class)],
        [],
      ),
    ],
    [attribute.class("inline-flex items-center justify-center"), ..attrs],
  )
}

pub fn icon_link(
  icon_class: String,
  href: String,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  html.a(
    [
      attribute.class("inline-flex items-center justify-center"),
      attribute.href(href),
    ],
    [icon(icon_class, attrs)],
  )
}

pub fn icon_label(
  icon_class: String,
  label: String,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  render(
    [
      html.i([attribute.class("leading-none " <> icon_class)], []),
      element.text(label),
    ],
    [attribute.class("inline-flex items-center gap-1.5"), ..attrs],
  )
}

pub fn primary() -> attribute.Attribute(msg) {
  attribute.class(
    "px-4 py-2 bg-violet-500 hover:not-disabled:bg-violet-700 text-white",
  )
}

pub fn secondary() -> attribute.Attribute(msg) {
  attribute.class("px-4 py-2 bg-zinc-800 hover:not-disabled:bg-zinc-700")
}

pub fn ghost() -> attribute.Attribute(msg) {
  attribute.class("text-zinc-400 hover:text-white")
}

pub fn ghost_inverse() -> attribute.Attribute(msg) {
  attribute.class("text-white hover:text-zinc-400 ")
}

pub fn danger() -> attribute.Attribute(msg) {
  attribute.class(
    "px-4 py-2 border border-red-500 text-red-500 hover:not-disabled:bg-red-500/10 font-bold",
  )
}
