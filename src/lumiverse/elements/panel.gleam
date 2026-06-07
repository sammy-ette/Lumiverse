import lumiverse/elements/button
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn shell(
  sidebar: List(element.Element(msg)),
  title: String,
  on_close: msg,
  body: element.Element(msg),
) -> element.Element(msg) {
  html.div(
    [
      attribute.class(
        "fixed flex justify-center items-center inset-0 z-50 bg-zinc-950/80",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "animate-enter-from-bottom bg-zinc-900 sm:border border-zinc-700 sm:rounded-xl flex max-sm:flex-col overflow-hidden w-full max-sm:h-full sm:w-[640px]",
          ),
        ],
        [
          html.div(
            [
              attribute.class(
                "sm:w-44 sm:border-r border-zinc-700 flex sm:flex-col gap-1 p-3 pt-4 shrink-0",
              ),
            ],
            sidebar,
          ),
          html.div([attribute.class("flex-1 flex flex-col min-w-0")], [
            html.div(
              [
                attribute.class(
                  "flex items-center justify-between px-6 py-4 border-b border-zinc-700",
                ),
              ],
              [
                html.h2([attribute.class("font-semibold text-white")], [
                  element.text(title),
                ]),
                button.icon("ph ph-[x]", "Close", [
                  button.ghost(),
                  event.on_click(on_close),
                ]),
              ],
            ),
            html.div([attribute.class("p-6 space-y-6 overflow-y-auto")], [
              body,
            ]),
          ]),
        ],
      ),
    ],
  )
}

pub fn group(
  title: String,
  children: List(element.Element(msg)),
) -> element.Element(msg) {
  html.div([attribute.class("space-y-3")], [
    html.p(
      [
        attribute.class(
          "text-xs text-zinc-500 uppercase tracking-wider font-medium",
        ),
      ],
      [element.text(title)],
    ),
    ..children
  ])
}

pub fn option_btn(label: String, active: Bool, msg: msg) -> element.Element(msg) {
  button.render(
    [
      case active {
        True ->
          html.i([attribute.class("ph ph-[check] text-violet-400 text-xs")], [])
        False -> element.none()
      },
      element.text(label),
    ],
    [
      attribute.class("flex items-center gap-2 px-4 py-2 border"),
      case active {
        True ->
          attribute.class("bg-violet-500/20 border-violet-500 text-violet-400")
        False ->
          attribute.class(
            "bg-zinc-800 border-zinc-700 text-zinc-300 hover:bg-zinc-700",
          )
      },
      event.on_click(msg),
    ],
  )
}

pub fn display_style_card(
  label: String,
  active: Bool,
  icon: element.Element(msg),
  msg: msg,
) -> element.Element(msg) {
  button.render(
    [
      icon,
      html.span(
        [
          attribute.class(case active {
            True -> "text-xs text-violet-400 font-medium"
            False -> "text-xs text-zinc-400"
          }),
        ],
        [element.text(label)],
      ),
    ],
    [
      attribute.class(
        "flex flex-col items-center justify-center gap-3 p-4 border w-28 h-28",
      ),
      case active {
        True -> attribute.class("border-violet-500 bg-violet-500/10")
        False ->
          attribute.class("border-zinc-700 bg-zinc-800 hover:border-zinc-500")
      },
      event.on_click(msg),
    ],
  )
}

pub fn section_btn(label: String, active: Bool, msg: msg) -> element.Element(msg) {
  button.button(label, [
    event.on_click(msg),
    attribute.class("w-full text-left font-normal px-3 py-2"),
    case active {
      True -> attribute.class("bg-violet-500/20 text-violet-400")
      False -> attribute.class("text-zinc-400 hover:bg-zinc-800")
    },
  ])
}
