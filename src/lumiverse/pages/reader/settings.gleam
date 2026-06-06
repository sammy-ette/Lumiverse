import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import localstorage
import lumiverse/elements/button
import lumiverse/pages/reader/model
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn default_prefs() -> model.ReaderPrefs {
  model.ReaderPrefs(
    direction: model.LTR,
    fit_mode: model.FitWidth,
    reading_mode: model.PageByPage,
    zoom: 100,
    scroll_speed: 300,
    preload_count: 3,
  )
}

pub fn load_prefs() -> model.ReaderPrefs {
  case localstorage.read("reader_prefs") {
    Error(_) -> default_prefs()
    Ok(s) ->
      case json.parse(s, prefs_decoder()) {
        Ok(p) -> p
        Error(_) -> default_prefs()
      }
  }
}

pub fn save_prefs_effect(prefs: model.ReaderPrefs) -> effect.Effect(model.Msg) {
  effect.from(fn(_) {
    localstorage.write("reader_prefs", prefs |> prefs_to_json |> json.to_string)
    Nil
  })
}

fn prefs_to_json(p: model.ReaderPrefs) -> json.Json {
  json.object([
    #(
      "direction",
      json.string(case p.direction {
        model.LTR -> "ltr"
        model.RTL -> "rtl"
      }),
    ),
    #(
      "fit_mode",
      json.string(case p.fit_mode {
        model.FitWidth -> "width"
        model.FitHeight -> "height"
        model.Original -> "original"
      }),
    ),
    #(
      "reading_mode",
      json.string(case p.reading_mode {
        model.PageByPage -> "page_by_page"
        model.LongStrip -> "long_strip"
      }),
    ),
    #("zoom", json.int(p.zoom)),
    #("scroll_speed", json.int(p.scroll_speed)),
    #("preload_count", json.int(p.preload_count)),
  ])
}

fn prefs_decoder() {
  use direction <- decode.field("direction", {
    use s <- decode.then(decode.string)
    decode.success(case s {
      "rtl" -> model.RTL
      _ -> model.LTR
    })
  })
  use fit_mode <- decode.field("fit_mode", {
    use s <- decode.then(decode.string)
    decode.success(case s {
      "height" -> model.FitHeight
      "original" -> model.Original
      _ -> model.FitWidth
    })
  })
  use reading_mode <- decode.field("reading_mode", {
    use s <- decode.then(decode.string)
    decode.success(case s {
      "long_strip" -> model.LongStrip
      _ -> model.PageByPage
    })
  })
  use zoom <- decode.field("zoom", decode.int)
  use scroll_speed <- decode.field("scroll_speed", decode.int)
  use preload_count <- decode.field("preload_count", decode.int)
  decode.success(model.ReaderPrefs(
    direction:,
    fit_mode:,
    reading_mode:,
    zoom:,
    scroll_speed:,
    preload_count:,
  ))
}

pub fn update(
  m: model.Model,
  msg: model.Msg,
) -> #(model.Model, effect.Effect(model.Msg)) {
  case msg {
    model.SwitchSection(section) -> #(
      model.Model(..m, settings_section: section),
      effect.none(),
    )
    model.SetDirection(direction) -> {
      let prefs = model.ReaderPrefs(..m.prefs, direction:)
      #(model.Model(..m, prefs:), save_prefs_effect(prefs))
    }
    model.SetFitMode(fit_mode) -> {
      let prefs = model.ReaderPrefs(..m.prefs, fit_mode:)
      #(model.Model(..m, prefs:), save_prefs_effect(prefs))
    }
    model.SetZoom(zoom) -> {
      let prefs = model.ReaderPrefs(..m.prefs, zoom:)
      #(model.Model(..m, prefs:), save_prefs_effect(prefs))
    }
    model.SetScrollSpeed(scroll_speed) -> {
      let prefs = model.ReaderPrefs(..m.prefs, scroll_speed:)
      #(model.Model(..m, prefs:), save_prefs_effect(prefs))
    }
    model.SetPreloadCount(preload_count) -> {
      let prefs = model.ReaderPrefs(..m.prefs, preload_count:)
      #(model.Model(..m, prefs:), save_prefs_effect(prefs))
    }
    model.SetReadingMode(reading_mode) -> #(
      model.Model(..m, reading_mode:),
      effect.none(),
    )
    _ -> #(m, effect.none())
  }
}

pub fn panel(m: model.Model) {
  case m.show_settings {
    False -> element.none()
    True -> view(m)
  }
}

fn view(m: model.Model) {
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
            [model.PageLayout]
              |> list.map(fn(s) { section_btn(s, m.settings_section) }),
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
                  element.text("Reader Settings"),
                ]),
                button.icon("ph ph-[x]", "Close settings", [
                  button.ghost(),
                  event.on_click(model.ToggleSettings),
                ]),
              ],
            ),
            html.div([attribute.class("p-6 space-y-6 overflow-y-auto")], [
              case m.settings_section {
                model.PageLayout -> page_layout_section(m)
                model.Header -> element.none()
                model.Keybinds -> element.none()
              },
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn section_btn(section: model.SettingsSection, active: model.SettingsSection) {
  let label = case section {
    model.PageLayout -> "Page Layout"
    model.Header -> "Header"
    model.Keybinds -> "Keybinds"
  }
  button.button(label, [
    event.on_click(model.SwitchSection(section)),
    attribute.class("w-full text-left font-normal px-3 py-2"),
    case section == active {
      True -> attribute.class("bg-violet-500/20 text-violet-400")
      False -> attribute.class("text-zinc-400 hover:bg-zinc-800")
    },
  ])
}

fn page_layout_section(m: model.Model) {
  html.div([attribute.class("space-y-6")], [
    settings_group("PAGE DISPLAY STYLE", [
      html.div([attribute.class("flex gap-3")], [
        display_style_card(
          "Single Page",
          m.reading_mode == model.PageByPage,
          single_page_icon(m.reading_mode == model.PageByPage),
          model.SetReadingMode(model.PageByPage),
        ),
        display_style_card(
          "Long Strip",
          m.reading_mode == model.LongStrip,
          long_strip_icon(m.reading_mode == model.LongStrip),
          model.SetReadingMode(model.LongStrip),
        ),
      ]),
    ]),
    settings_group("IMAGE FIT", [
      html.div([attribute.class("flex gap-2 flex-wrap")], [
        option_btn(
          "Fit Width",
          m.prefs.fit_mode == model.FitWidth,
          model.SetFitMode(model.FitWidth),
        ),
        option_btn(
          "Fit Height",
          m.prefs.fit_mode == model.FitHeight,
          model.SetFitMode(model.FitHeight),
        ),
        option_btn(
          "Natural Size",
          m.prefs.fit_mode == model.Original,
          model.SetFitMode(model.Original),
        ),
      ]),
    ]),
    settings_group("READING DIRECTION", [
      html.div([attribute.class("flex gap-2 flex-wrap")], [
        option_btn(
          "Left to Right",
          m.prefs.direction == model.LTR,
          model.SetDirection(model.LTR),
        ),
        option_btn(
          "Right to Left",
          m.prefs.direction == model.RTL,
          model.SetDirection(model.RTL),
        ),
      ]),
    ]),
  ])
}

fn settings_group(
  title: String,
  children: List(element.Element(model.Msg)),
) -> element.Element(model.Msg) {
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

fn display_style_card(
  label: String,
  active: Bool,
  icon: element.Element(model.Msg),
  msg: model.Msg,
) {
  html.button(
    [
      attribute.class(
        "flex flex-col items-center justify-center gap-3 p-4 rounded-xl border w-28 h-28 cursor-pointer transition-colors",
      ),
      case active {
        True -> attribute.class("border-violet-500 bg-violet-500/10")
        False ->
          attribute.class("border-zinc-700 bg-zinc-800 hover:border-zinc-500")
      },
      event.on_click(msg),
    ],
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
  )
}

fn single_page_icon(active: Bool) {
  let color = case active {
    True -> "bg-violet-500"
    False -> "bg-zinc-600"
  }
  html.div([attribute.class("flex items-center justify-center")], [
    html.div([attribute.class("w-7 h-10 rounded " <> color)], []),
  ])
}

fn long_strip_icon(active: Bool) {
  let color = case active {
    True -> "bg-violet-500"
    False -> "bg-zinc-600"
  }
  html.div(
    [attribute.class("flex flex-col items-center justify-center gap-[5px]")],
    [
      html.div([attribute.class("w-10 h-[9px] rounded " <> color)], []),
      html.div([attribute.class("w-10 h-[9px] rounded " <> color)], []),
      html.div([attribute.class("w-10 h-[9px] rounded " <> color)], []),
    ],
  )
}

fn option_btn(label: String, active: Bool, msg: model.Msg) {
  let base =
    "flex items-center gap-2 px-4 py-2 rounded-lg border text-sm cursor-pointer transition-colors outline-none"
  html.button(
    [
      attribute.class(base),
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
    [
      case active {
        True ->
          html.i([attribute.class("ph ph-[check] text-violet-400 text-xs")], [])
        False -> element.none()
      },
      element.text(label),
    ],
  )
}

pub fn zoom_label(zoom: Int) -> String {
  int.to_string(zoom) <> "%"
}
