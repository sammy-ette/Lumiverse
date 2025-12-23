import lustre/attribute
import lustre/element
import lustre/element/html

pub type Color {
  Neutral
  Primary
}

pub fn button(
  attrs: List(attribute.Attribute(a)),
  elems: List(element.Element(a)),
) {
  html.button(
    [
      attribute.class(
        "rounded flex gap-2 items-center justify-center transition hover:opacity-80 active:scale-[95%] outline-none",
      ),
      ..attrs
    ],
    elems,
  )
}

pub fn bg(color: Color) -> attribute.Attribute(a) {
  case color {
    Primary -> "bg-violet-500"
    Neutral -> "bg-zinc-500"
  }
  |> attribute.class
}

pub fn sm() {
  attribute.class("rounded px-3.5 py-1.5 text-sm")
}

pub fn md() {
  attribute.class("rounded px-4 py-2 text-base")
}

pub fn lg() {
  attribute.class("rounded px-5 py-2.5 text-lg")
}
