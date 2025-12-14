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
        "rounded-md flex p-2 items-center justify-center transition hover:opacity-80 active:scale-[95%]",
      ),
      ..attrs
    ],
    elems,
  )
}

pub fn bg(color: Color) -> attribute.Attribute(a) {
  case color {
    Primary -> "bg-sky-500"
    Neutral -> "bg-zinc-500"
  }
  |> attribute.class
}
