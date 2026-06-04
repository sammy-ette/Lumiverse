import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type MenuItem(msg) {
  MenuItem(
    label: String,
    subtitle: option.Option(String),
    on_click: msg,
    icon: option.Option(String),
    active: Bool,
  )
  MenuDivider
}

pub fn dropdown(
  open: Bool,
  on_toggle: msg,
  trigger: Element(msg),
  items: List(MenuItem(msg)),
) -> Element(msg) {
  html.div([attribute.class("relative inline-block")], [
    html.div(
      [attribute.class("cursor-pointer select-none"), event.on_click(on_toggle)],
      [trigger],
    ),
    case open {
      False -> element.none()
      True ->
        html.div(
          [
            attribute.class("fixed inset-0 z-40"),
            event.on_click(on_toggle),
          ],
          [],
        )
    },
    html.div(
      [
        attribute.class(
          "absolute right-0 top-full mt-2 bg-zinc-900 border border-zinc-800 rounded-xl z-50 min-w-56 shadow-xl p-1.5 "
          <> case open {
            True -> "block"
            False -> "hidden"
          },
        ),
      ],
      list.map(items, fn(item) {
        case item {
          MenuItem(label, subtitle, on_click, icon, active) ->
            html.button(
              [
                attribute.class(
                  "w-full flex items-center gap-3 px-2 py-2 rounded-lg transition-all duration-150 select-none disabled:opacity-40 disabled:cursor-not-allowed "
                  <> case active {
                    True -> "bg-zinc-700/30"
                    False -> "hover:bg-zinc-700/50"
                  },
                ),
                event.on_click(on_click),
              ],
              [
                case icon {
                  option.Some(icon_name) ->
                    html.div(
                      [
                        attribute.class(
                          "w-9 h-9 rounded-lg flex items-center justify-center shrink-0 "
                          <> case active {
                            True -> "bg-violet-500"
                            False -> "bg-zinc-700"
                          },
                        ),
                      ],
                      [
                        html.i(
                          [attribute.class(icon_name <> " text-lg text-white")],
                          [],
                        ),
                      ],
                    )
                  option.None -> element.none()
                },
                html.div(
                  [attribute.class("flex flex-col text-left flex-1")],
                  [
                    html.span(
                      [
                        attribute.class(
                          "text-sm font-semibold "
                          <> case active {
                            True -> "text-white"
                            False -> "text-zinc-200"
                          },
                        ),
                      ],
                      [html.text(label)],
                    ),
                    case subtitle {
                      option.Some(sub) ->
                        html.span(
                          [attribute.class("text-xs text-zinc-400")],
                          [html.text(sub)],
                        )
                      option.None -> element.none()
                    },
                  ],
                ),
              ],
            )
          MenuDivider ->
            html.div([attribute.class("border-t border-zinc-700 my-1")], [])
        }
      }),
    ),
  ])
}
