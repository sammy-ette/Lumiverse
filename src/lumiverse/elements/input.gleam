import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn input(attrs: List(attribute.Attribute(a))) {
  html.input([
    attribute.class(
      "bg-zinc-800 rounded-md px-3 py-2 text-zinc-200 outline-none border border-zinc-700/50 focus:border-violet-500/50 focus:ring-2 focus:ring-violet-500/20 transition-colors",
    ),
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
