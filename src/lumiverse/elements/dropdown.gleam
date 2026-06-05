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
  MenuToggle(
    label: String,
    subtitle: option.Option(String),
    on_click: msg,
    icon: option.Option(String),
    active: Bool,
  )
  MenuDivider
  MenuNone
  MenuCustom(Element(msg))
  MenuCustomWrapped(icon: String, elem: Element(msg))
}

pub type Align {
  AlignLeft
  AlignRight
}

pub fn dropdown(
  open: Bool,
  on_toggle: msg,
  trigger: Element(msg),
  items: List(MenuItem(msg)),
) -> Element(msg) {
  dropdown_aligned(open, on_toggle, trigger, items, AlignRight)
}

pub fn dropdown_aligned(
  open: Bool,
  on_toggle: msg,
  trigger: Element(msg),
  items: List(MenuItem(msg)),
  align: Align,
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
            attribute.class("fixed inset-0 h-screen z-40"),
            event.on_click(on_toggle),
          ],
          [],
        )
    },
    html.div(
      [
        attribute.class(
          "ml-3 absolute top-full mt-2 bg-zinc-900 border border-zinc-800 rounded-xl z-50 min-w-56 shadow-xl p-1.5 "
          <> case align {
            AlignLeft -> "left-0 "
            AlignRight -> "right-0 "
          }
          <> case open {
            True -> "block"
            False -> "hidden"
          },
        ),
      ],
      list.map(items, fn(item) {
        case item {
          MenuNone -> element.none()
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
                dropdown_icon(icon, active),
                html.div([attribute.class("flex flex-col text-left flex-1")], [
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
                      html.span([attribute.class("text-xs text-zinc-400")], [
                        html.text(sub),
                      ])
                    option.None -> element.none()
                  },
                ]),
              ],
            )
          MenuToggle(label, subtitle, on_click, icon, active) ->
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
                dropdown_icon(icon, active),
                html.div([attribute.class("flex flex-col text-left flex-1")], [
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
                      html.span([attribute.class("text-xs text-zinc-400")], [
                        html.text(sub),
                      ])
                    option.None -> element.none()
                  },
                ]),
                html.div(
                  [
                    attribute.class(
                      "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors "
                      <> case active {
                        True -> "bg-violet-600"
                        False -> "bg-zinc-600"
                      },
                    ),
                  ],
                  [
                    html.input([
                      attribute.type_("checkbox"),
                      attribute.checked(active),
                      attribute.class("sr-only"),
                    ]),
                    html.span(
                      [
                        attribute.class(
                          "inline-block h-3.5 w-3.5 rounded-full bg-white shadow transition-transform "
                          <> case active {
                            True -> "translate-x-4.5"
                            False -> "translate-x-0.5"
                          },
                        ),
                      ],
                      [],
                    ),
                  ],
                ),
              ],
            )
          MenuDivider ->
            html.div([attribute.class("border-t border-zinc-700 my-1")], [])
          MenuCustom(el) -> el
          MenuCustomWrapped(icon, el) ->
            html.button(
              [
                attribute.class(
                  "w-full flex items-center gap-3 px-2 py-2 rounded-lg transition-all duration-150 select-none disabled:opacity-40 disabled:cursor-not-allowed",
                ),
              ],
              [dropdown_icon(option.Some(icon), False), el],
            )
        }
      }),
    ),
  ])
}

pub fn dropdown_icon(icon: option.Option(String), active: Bool) {
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
          html.i([attribute.class(icon_name <> " text-lg text-white")], []),
        ],
      )
    option.None -> element.none()
  }
}
