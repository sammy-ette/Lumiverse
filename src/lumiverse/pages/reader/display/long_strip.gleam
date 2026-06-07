import gleam/dynamic/decode
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

pub fn view(
  m: model.Model,
  progress: reader.Progress,
  page_image_url: fn(Int) -> String,
) {
  let image_class = case m.prefs.fit_mode {
    model.FitWidth -> "w-full h-auto max-h-screen object-contain"
    model.FitHeight -> "h-screen w-auto object-contain"
    model.Original -> "object-contain"
  }

  html.div(
    [
      attribute.class("flex flex-col overflow-y-auto"),
      attribute.id("reader-content"),
      event.on("scroll", decode.success(model.LongStripScroll)),
    ],
    list.append(
      list.map(utils.range(0, m.strip_loaded), fn(i) {
        html.img([
          attribute.attribute("data-src", page_image_url(i)),
          attribute.class(image_class),
        ])
      }),
      [
        case m.chapter_info {
          option.None -> element.none()
          option.Some(info) ->
            case m.strip_loaded == info.pages - 1 {
              False -> element.none()
              True ->
                html.div(
                  [
                    attribute.class(
                      "p-4 flex flex-col items-center justify-center gap-2",
                    ),
                  ],
                  [
                    html.p([attribute.class("text-sm text-zinc-500")], [
                      element.text("You've reached the end!"),
                    ]),
                    button.button("Next", [
                      button.primary(),
                      event.on_click(model.EndStrip),
                    ]),
                  ],
                )
            }
        },
      ],
    ),
  )
}
