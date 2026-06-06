import gleam/list
import lumiverse/elements/button
import lumiverse/pages/reader/model
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn overlay(m: model.Model) {
  case m.show_hint {
    True -> view()
    False -> element.none()
  }
}

fn view() {
  html.div(
    [attribute.class("absolute inset-0 z-50 bg-zinc-950/90 flex flex-col")],
    [
      html.div([attribute.class("flex flex-1")], [
        html.div(
          [
            attribute.class(
              "w-1/2 flex flex-col items-center justify-center gap-3 border-r border-zinc-700 hover:bg-white/5 transition-colors cursor-pointer select-none",
            ),
            event.on_click(model.DismissHint),
          ],
          [
            html.i(
              [attribute.class("ph ph-[arrow-left] text-6xl text-white")],
              [],
            ),
            html.span([attribute.class("text-lg font-semibold text-white")], [
              element.text("Previous Page"),
            ]),
            html.span([attribute.class("text-sm text-zinc-400")], [
              element.text("tap / click this half"),
            ]),
          ],
        ),
        html.div(
          [
            attribute.class(
              "w-1/2 flex flex-col items-center justify-center gap-3 hover:bg-white/5 transition-colors cursor-pointer select-none",
            ),
            event.on_click(model.DismissHint),
          ],
          [
            html.i(
              [attribute.class("ph ph-[arrow-right] text-6xl text-white")],
              [],
            ),
            html.span([attribute.class("text-lg font-semibold text-white")], [
              element.text("Next Page"),
            ]),
            html.span([attribute.class("text-sm text-zinc-400")], [
              element.text("tap / click this half"),
            ]),
          ],
        ),
      ]),
      html.div(
        [
          attribute.class(
            "border-t border-zinc-800 px-6 py-4 flex items-center justify-between gap-4",
          ),
        ],
        [
          html.div([attribute.class("hidden sm:flex gap-6 text-sm")], [
            hint_keys(["←", "A", "H"], "Previous"),
            hint_keys(["→", "D", "L"], "Next"),
            hint_keys(["Z"], "Zen mode"),
          ]),
          html.p([attribute.class("sm:hidden text-sm text-zinc-400")], [
            element.text("Tap either half to navigate"),
          ]),
          button.button("Understood!", [
            button.primary(),
            event.on_click(model.DismissHint),
          ]),
        ],
      ),
    ],
  )
}

fn hint_keys(keys: List(String), action: String) -> element.Element(model.Msg) {
  html.div(
    [attribute.class("flex items-center gap-1.5 text-zinc-300")],
    list.append(list.map(keys, hint_key), [
      html.span([attribute.class("text-zinc-400 mx-1")], [element.text("→")]),
      html.span([], [element.text(action)]),
    ]),
  )
}

fn hint_key(label: String) -> element.Element(model.Msg) {
  html.kbd(
    [
      attribute.class(
        "inline-flex items-center justify-center min-w-[1.6rem] h-6 px-1.5 rounded bg-zinc-700 border border-zinc-600 text-xs font-mono text-zinc-200",
      ),
    ],
    [element.text(label)],
  )
}
