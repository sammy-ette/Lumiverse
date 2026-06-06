import gleam/int
import gleam/option
import lumiverse/elements/button
import lumiverse/pages/reader/model
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn panel(m: model.Model) {
  let slide_class = case m.show_menu {
    True -> "translate-x-0"
    False -> "translate-x-full"
  }
  let backdrop_class = case m.show_menu {
    True -> "opacity-100"
    False -> "opacity-0 pointer-events-none"
  }

  html.div(
    [
      attribute.class("fixed inset-0 z-60 overflow-hidden"),
      case m.show_menu {
        True -> attribute.class("")
        False -> attribute.class("pointer-events-none")
      },
    ],
    [
      html.div(
        [
          attribute.class(
            "absolute inset-0 bg-zinc-950/60 transition-opacity duration-300 "
            <> backdrop_class,
          ),
          event.on_click(model.ToggleMenu),
        ],
        [],
      ),
      html.div(
        [
          attribute.class(
            "z-55 absolute top-0 right-0 bottom-0 w-72 bg-zinc-950 border-l border-zinc-800 flex flex-col transition-transform duration-300 ease-in-out pointer-events-auto "
            <> slide_class,
          ),
        ],
        [
          html.div(
            [
              attribute.class(
                "flex items-center justify-between px-4 py-3 border-b border-zinc-800",
              ),
            ],
            [
              html.span(
                [
                  attribute.class(
                    "text-xs text-zinc-500 uppercase tracking-widest font-medium",
                  ),
                ],
                [element.text("Menu")],
              ),
              button.icon("ph ph-[x]", "Close menu", [
                button.ghost(),
                event.on_click(model.ToggleMenu),
              ]),
            ],
          ),
          html.div([attribute.class("flex flex-col")], [
            menu_section("Series", [series_row(m)]),
            menu_section("Chapter/Volume", [chapter_nav(m)]),
            menu_section("Page", [page_nav(m)]),
            menu_section("", [reader_settings()]),
          ]),
        ],
      ),
    ],
  )
}

fn menu_section(
  title: String,
  children: List(element.Element(model.Msg)),
) -> element.Element(model.Msg) {
  html.div([attribute.class("px-4 py-4 border-b border-zinc-800 space-y-3")], [
    html.span(
      [
        attribute.class(
          "text-xs text-zinc-500 uppercase tracking-widest font-medium",
        ),
      ],
      [element.text(title)],
    ),
    ..children
  ])
}

fn series_row(m: model.Model) -> element.Element(model.Msg) {
  case m.chapter_info {
    option.None ->
      html.div(
        [attribute.class("h-9 bg-zinc-800 animate-pulse rounded-lg")],
        [],
      )
    option.Some(info) ->
      html.div(
        [
          attribute.class(
            "flex items-center gap-3 bg-zinc-900 rounded-lg px-3 py-2",
          ),
        ],
        [
          html.i(
            [
              attribute.class(
                "ph ph-[book-open] text-zinc-400 text-lg shrink-0",
              ),
            ],
            [],
          ),
          html.span([attribute.class("text-sm text-zinc-200 truncate")], [
            element.text(info.series_name),
          ]),
        ],
      )
  }
}

fn chapter_nav(m: model.Model) -> element.Element(model.Msg) {
  let prev_attr = case m.prev_chapter {
    option.None -> attribute.disabled(True)
    option.Some(id) -> attribute.href("/read/" <> int.to_string(id))
  }
  let next_attr = case m.next_chapter {
    option.None -> attribute.disabled(True)
    option.Some(id) -> attribute.href("/read/" <> int.to_string(id))
  }

  html.div([attribute.class("flex items-center gap-2")], [
    button.icon("ph ph-[caret-left]", "Previous chapter", [
      button.secondary(),
      prev_attr,
    ]),
    html.div([attribute.class("flex-1 text-center")], case m.chapter_info {
      option.None -> [
        html.div(
          [attribute.class("h-4 bg-zinc-800 animate-pulse rounded mx-4")],
          [],
        ),
      ]
      option.Some(info) -> [
        html.p([attribute.class("text-sm font-semibold text-zinc-200")], [
          element.text(info.subtitle),
        ]),
      ]
    }),
    button.icon("ph ph-[caret-right]", "Next chapter", [
      button.secondary(),
      next_attr,
    ]),
  ])
}

fn page_nav(m: model.Model) -> element.Element(model.Msg) {
  let #(page_num, total_pages) = case m.progress, m.chapter_info {
    option.Some(Ok(p)), option.Some(info) -> #(p.page_number + 1, info.pages)
    _, _ -> #(0, 0)
  }

  html.div([attribute.class("flex items-center gap-2")], [
    button.icon("ph ph-[caret-left]", "Previous page", [
      button.secondary(),
      event.on_click(model.Previous),
    ]),
    html.div([attribute.class("flex-1 text-center")], [
      html.p([attribute.class("text-sm font-semibold text-zinc-200")], [
        element.text(int.to_string(page_num)),
      ]),
      html.p([attribute.class("text-xs text-zinc-400")], [
        element.text("of " <> int.to_string(total_pages)),
      ]),
    ]),
    button.icon("ph ph-[caret-right]", "Next page", [
      button.secondary(),
      event.on_click(model.Next),
    ]),
  ])
}

fn reader_settings() {
  button.icon_label("ph ph-[gear]", "Reader Settings", [
    button.secondary(),
    attribute.class("w-full justify-start"),
    event.on_click(model.ToggleSettings),
  ])
}

pub fn update(
  m: model.Model,
  msg: model.Msg,
) -> #(model.Model, effect.Effect(model.Msg)) {
  case msg {
    model.ToggleMenu -> #(
      model.Model(..m, show_menu: !m.show_menu),
      effect.none(),
    )
    _ -> #(m, effect.none())
  }
}
