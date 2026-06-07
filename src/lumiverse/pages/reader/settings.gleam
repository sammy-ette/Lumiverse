import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import localstorage
import lumiverse/elements/panel
import lumiverse/pages/reader/model
import lumiverse/pages/reader/utils
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html

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
      case reading_mode {
        model.LongStrip -> effect.from(fn(_) { utils.observe_lazy_images() })
        model.PageByPage -> effect.none()
      },
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
  panel.shell(
    [model.PageLayout]
      |> list.map(fn(s) {
        panel.section_btn(section_label(s), s == m.settings_section, model.SwitchSection(s))
      }),
    "Reader Settings",
    model.ToggleSettings,
    case m.settings_section {
      model.PageLayout -> page_layout_section(m)
      model.Header -> element.none()
      model.Keybinds -> element.none()
    },
  )
}

fn section_label(section: model.SettingsSection) -> String {
  case section {
    model.PageLayout -> "Page Layout"
    model.Header -> "Header"
    model.Keybinds -> "Keybinds"
  }
}

fn page_layout_section(m: model.Model) {
  html.div([attribute.class("space-y-6")], [
    panel.group("PAGE DISPLAY STYLE", [
      html.div([attribute.class("flex gap-3")], [
        panel.display_style_card(
          "Single Page",
          m.reading_mode == model.PageByPage,
          single_page_icon(m.reading_mode == model.PageByPage),
          model.SetReadingMode(model.PageByPage),
        ),
        panel.display_style_card(
          "Long Strip",
          m.reading_mode == model.LongStrip,
          long_strip_icon(m.reading_mode == model.LongStrip),
          model.SetReadingMode(model.LongStrip),
        ),
      ]),
    ]),
    panel.group("IMAGE FIT", [
      html.div([attribute.class("flex gap-2 flex-wrap")], [
        panel.option_btn(
          "Fit Width",
          m.prefs.fit_mode == model.FitWidth,
          model.SetFitMode(model.FitWidth),
        ),
        panel.option_btn(
          "Fit Height",
          m.prefs.fit_mode == model.FitHeight,
          model.SetFitMode(model.FitHeight),
        ),
        panel.option_btn(
          "Natural Size",
          m.prefs.fit_mode == model.Original,
          model.SetFitMode(model.Original),
        ),
      ]),
    ]),
    panel.group("READING DIRECTION", [
      html.div([attribute.class("flex gap-2 flex-wrap")], [
        panel.option_btn(
          "Left to Right",
          m.prefs.direction == model.LTR,
          model.SetDirection(model.LTR),
        ),
        panel.option_btn(
          "Right to Left",
          m.prefs.direction == model.RTL,
          model.SetDirection(model.RTL),
        ),
      ]),
    ]),
  ])
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

pub fn zoom_label(zoom: Int) -> String {
  int.to_string(zoom) <> "%"
}
