import gleam/int
import gleam/option.{None, Some}
import lumiverse/api/prefs
import lumiverse/elements/button
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

type Model {
  Model(quality_enabled: Bool, quality: Int)
}

type Msg {
  SetQualityEnabled(Bool)
  SetQuality(Int)
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "preferences-page")
}

pub fn element() {
  element.element(
    "preferences-page",
    [attribute.class("flex-1 flex w-full h-full flex-col p-4")],
    [],
  )
}

fn init(_) {
  let #(enabled, quality) = case prefs.image_quality() {
    None -> #(False, 85)
    Some(q) -> #(True, q)
  }
  #(Model(quality_enabled: enabled, quality: quality), effect.none())
}

fn update(m: Model, msg: Msg) {
  case msg {
    SetQualityEnabled(enabled) -> {
      case enabled {
        False -> prefs.set_image_quality(None)
        True ->
          prefs.set_image_quality(Some(
            prefs.image_quality() |> option.unwrap(85),
          ))
      }
      #(m, effect.none())
    }
    SetQuality(q) -> {
      prefs.set_image_quality(Some(q))
      #(m, effect.none())
    }
  }
}

fn view(_m: Model) {
  let quality = prefs.image_quality()
  let quality_enabled = option.is_some(quality)
  let quality_value = option.unwrap(quality, 85)
  html.div([attribute.class("max-w-xl space-y-8")], [
    html.div([attribute.class("space-y-1")], [
      html.h1([attribute.class("text-3xl font-bold")], [
        element.text("Preferences"),
      ]),
      html.p([attribute.class("text-zinc-400 text-sm")], [
        element.text("Settings are stored on this device only."),
      ]),
    ]),
    html.div([attribute.class("space-y-4")], [
      html.h2([attribute.class("text-lg font-semibold text-zinc-200")], [
        element.text("Display"),
      ]),
      html.div([attribute.class("bg-zinc-900 rounded-md p-4 space-y-4")], [
        html.label(
          [
            attribute.class(
              "flex items-center gap-3 cursor-pointer select-none",
            ),
          ],
          [
            html.input([
              attribute.type_("checkbox"),
              attribute.checked(quality_enabled),
              attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
              event.on_check(SetQualityEnabled),
            ]),
            html.div([attribute.class("space-y-0.5")], [
              html.span([attribute.class("text-sm font-medium text-zinc-200")], [
                element.text("Reduce image quality"),
              ]),
              html.p([attribute.class("text-xs text-zinc-400")], [
                element.text(
                  "Lower quality means smaller files and faster loading on slow connections.",
                ),
              ]),
            ]),
          ],
        ),
        case quality_enabled {
          False -> element.none()
          True ->
            html.div([attribute.class("space-y-2 pl-7")], [
              html.div(
                [attribute.class("flex items-center justify-between text-sm")],
                [
                  html.span([attribute.class("text-zinc-400")], [
                    element.text("Quality"),
                  ]),
                  html.span(
                    [attribute.class("text-zinc-200 font-mono w-8 text-right")],
                    [
                      element.text(int.to_string(quality_value)),
                    ],
                  ),
                ],
              ),
              html.input([
                attribute.type_("range"),
                attribute.attribute("min", "1"),
                attribute.attribute("max", "100"),
                attribute.attribute("step", "1"),
                attribute.value(int.to_string(quality_value)),
                attribute.class("w-full accent-violet-500 cursor-pointer"),
                event.on_input(fn(v) {
                  case int.parse(v) {
                    Ok(q) -> SetQuality(q)
                    Error(_) -> SetQuality(quality_value)
                  }
                }),
              ]),
              html.div(
                [
                  attribute.class("flex justify-between text-xs text-zinc-500"),
                ],
                [
                  html.span([], [element.text("Less Data Usage")]),
                  html.span([], [element.text("Higher Quality")]),
                ],
              ),
            ])
        },
      ]),
      button.button("Reset to defaults", [
        attribute.type_("button"),
        event.on_click(SetQualityEnabled(False)),
      ]),
    ]),
  ])
}
