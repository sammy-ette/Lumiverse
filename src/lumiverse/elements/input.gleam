import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn input(attrs: List(attribute.Attribute(a))) {
  html.input([
    attribute.class("bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none"),
    ..attrs
  ])
}

pub fn input_with_name(name: String, attrs: List(attribute.Attribute(a))) {
  html.div([attribute.class("space-y-2")], [
    label(name),
    input([
      attribute.name(name |> string.lowercase |> string.replace(" ", "_")),
      ..attrs
    ]),
  ])
}

pub fn label(name: String) {
  html.label(
    [
      attribute.for(name),
      attribute.class("block font-semibold text-md text-zinc-300"),
    ],
    [element.text(name)],
  )
}
