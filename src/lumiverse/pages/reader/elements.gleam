import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import lumiverse/api/reader
import lumiverse/elements/button
import lumiverse/pages/reader/model
import lumiverse/pages/reader/utils
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn reader_header(m: model.Model) {
  html.div(
    [
      attribute.class(
        "flex items-center justify-between p-4 border-b border-zinc-800 bg-zinc-950",
      ),
      case m.reading_mode {
        model.LongStrip -> attribute.class("sticky top-0 left-0 right-0")
        model.PageByPage -> attribute.none()
      },
    ],
    [
      html.div([attribute.class("flex items-center gap-4")], [
        case m.chapter_info {
          option.None ->
            button.icon("ph ph-[arrow-left]", "Back to series", [
              button.ghost(),
              attribute.disabled(True),
            ])
          option.Some(info) ->
            button.icon_link(
              "ph ph-[arrow-left]",
              "Back to series",
              "/series/" <> int.to_string(info.series_id),
              [button.ghost()],
            )
        },
        html.div([attribute.class("flex flex-wrap gap-4 items-center")], [
          html.h1(
            [
              attribute.class(
                "min-w-0 truncate text-violet-400 sm:text-lg font-bold",
              ),
            ],
            [
              case m.chapter_info {
                option.None -> element.none()
                option.Some(info) -> element.text(info.series_name)
              },
            ],
          ),
          html.h2([attribute.class("max-sm:hidden text-sm text-zinc-300")], [
            case m.chapter_info {
              option.None -> element.none()
              option.Some(info) -> element.text(info.subtitle)
            },
          ]),
        ]),
      ]),
      html.div([attribute.class("flex items-center gap-4")], [
        html.div([attribute.class("max-sm:hidden contents")], [
          nav_chapter_btn(
            m.prev_chapter,
            "ph ph-[skip-back]",
            "Previous chapter",
          ),
          nav_chapter_btn(
            m.next_chapter,
            "ph ph-[skip-forward]",
            "Next chapter",
          ),
        ]),
        button.icon("ph ph-[arrows-out-simple]", "Zen mode", [
          button.ghost(),
          event.on_click(model.ToggleZen),
          attribute.title("Toggle Zen Mode (Focused & Fullscreen Reading)"),
        ]),
        button.icon("ph ph-[gear]", "Settings", [
          button.ghost(),
          attribute.class("max-sm:hidden"),
          event.on_click(model.ToggleSettings),
        ]),
        button.icon("ph ph-[list]", "Menu", [
          button.ghost(),
          event.on_click(model.ToggleMenu),
        ]),
      ]),
    ],
  )
}

fn nav_chapter_btn(chapter: option.Option(Int), icon: String, label: String) {
  case chapter {
    option.None ->
      button.icon(icon, label, [button.ghost(), attribute.disabled(True)])
    option.Some(id) ->
      button.icon_link(icon, label, "/read/" <> int.to_string(id), [
        button.ghost(),
      ])
  }
}

pub fn progress_scrubber(m: model.Model, progress: reader.Progress) {
  let pages = case m.chapter_info {
    option.Some(info) -> info.pages
    option.None -> 1
  }
  let fill_pct =
    int.to_float(progress.page_number + 1) /. int.to_float(pages) *. 100.0

  let page_label = case m.chapter_info {
    option.None ->
      html.div(
        [attribute.class("bg-zinc-700 animate-pulse h-3.5 w-12 rounded")],
        [],
      )
    option.Some(info) ->
      case m.editing_page {
        True ->
          html.input([
            attribute.class(
              "w-12 text-center bg-zinc-800 rounded text-xs text-zinc-200 outline-none border border-zinc-600 focus:border-violet-500 tabular-nums py-0",
            ),
            attribute.type_("number"),
            attribute.attribute("autofocus", ""),
            event.on("keydown", {
              use key <- decode.subfield(["key"], decode.string)
              use value <- decode.subfield(["target", "value"], decode.string)
              case key {
                "Enter" -> decode.success(model.ConfirmPageEdit(value))
                "Escape" -> decode.success(model.ConfirmPageEdit(""))
                _ -> decode.failure(model.EditPage, "not enter/escape")
              }
            }),
            event.on("blur", {
              use v <- decode.subfield(["target", "value"], decode.string)
              decode.success(model.ConfirmPageEdit(v))
            }),
          ])
        False ->
          button.button(
            int.to_string(progress.page_number + 1)
              <> "/"
              <> int.to_string(info.pages),
            [
              button.ghost(),
              attribute.class("text-xs tabular-nums"),
              event.on_click(model.EditPage),
            ],
          )
      }
  }

  let scrub_bar = case pages <= 100 {
    False ->
      html.div(
        [
          attribute.class(
            "h-full bg-zinc-800 relative rounded-sm overflow-hidden",
          ),
          event.on("click", {
            use x <- decode.subfield(["offsetX"], decode.float)
            use width <- decode.subfield(
              ["currentTarget", "offsetWidth"],
              decode.float,
            )
            let page =
              float.truncate(x /. width *. int.to_float(pages))
              |> int.clamp(min: 0, max: pages - 1)
            decode.success(model.GoToPage(page))
          }),
        ],
        [
          html.div(
            [
              attribute.class("h-full bg-violet-500 pointer-events-none"),
              attribute.style("width", float.to_string(fill_pct) <> "%"),
            ],
            [],
          ),
        ],
      )
    True ->
      html.div(
        [attribute.class("flex h-full gap-px")],
        list.map(utils.range(0, pages - 1), fn(i) {
          html.div(
            [
              attribute.class(
                "flex-1 rounded-sm transition-colors cursor-pointer "
                <> case i <= progress.page_number {
                  True -> "bg-violet-500"
                  False -> "bg-zinc-700 hover:bg-violet-400"
                },
              ),
              event.on_click(model.GoToPage(i)),
            ],
            [],
          )
        }),
      )
  }

  let show = case m.scrubber_hovered {
    True -> attribute.class("max-w-8 max-h-8 opacity-100")
    False -> attribute.class("max-w-0 max-h-0 opacity-0 overflow-hidden")
  }
  let show_label = case m.scrubber_hovered {
    True -> attribute.class("max-w-16 max-h-8 opacity-100")
    False -> attribute.class("max-w-0 max-h-0 opacity-0 overflow-hidden")
  }

  html.div(
    [
      attribute.class(
        "absolute bottom-0 left-0 right-0 z-20 flex flex-col justify-end pb-0 pt-10",
      ),
      event.on("mouseover", decode.success(model.ScrubberHover(True))),
      event.on("mouseleave", decode.success(model.ScrubberHover(False))),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex items-center gap-2 px-3 bg-zinc-950/80 backdrop-blur-sm transition-all duration-300 ease-in-out",
          ),
          case m.scrubber_hovered {
            True -> attribute.class("py-1.5")
            False -> attribute.class("py-0")
          },
        ],
        [
          button.icon("ph ph-[caret-left]", "Previous page", [
            button.ghost(),
            attribute.class("shrink-0 transition-all duration-300 ease-in-out"),
            show,
            event.on_click(model.Previous),
          ]),
          html.div(
            [
              attribute.class(
                "flex-1 rounded-sm overflow-hidden transition-all duration-300 ease-in-out",
              ),
              case m.scrubber_hovered {
                True -> attribute.class("h-2")
                False -> attribute.class("h-1")
              },
            ],
            [
              scrub_bar,
            ],
          ),
          html.div(
            [
              attribute.class(
                "text-xs text-zinc-400 transition-all duration-300 ease-in-out",
              ),
              show_label,
            ],
            [page_label],
          ),
          button.icon("ph ph-[caret-right]", "Next page", [
            button.ghost(),
            attribute.class("shrink-0 transition-all duration-300 ease-in-out"),
            show,
            event.on_click(model.Next),
          ]),
        ],
      ),
    ],
  )
}
