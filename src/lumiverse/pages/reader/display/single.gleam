import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import lumiverse/api/reader
import lumiverse/pages/reader/elements
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
  html.div(
    [
      attribute.class("relative h-screen overflow-hidden flex flex-col"),
      attribute.id("reader-content"),
    ],
    [
      page_view(m, progress, page_image_url),
      elements.progress_scrubber(m, progress),
    ],
  )
}

fn page_view(
  m: model.Model,
  progress: reader.Progress,
  page_image_url: fn(Int) -> String,
) {
  let image_class = case m.prefs.fit_mode {
    model.FitWidth -> "w-full h-auto max-h-screen object-contain"
    model.FitHeight -> "h-screen w-auto object-contain"
    model.Original -> "object-contain"
  }
  let scale =
    "scale(" <> float.to_string(int.to_float(m.prefs.zoom) /. 100.0) <> ")"

  html.div(
    [
      attribute.class(
        "flex-1 relative sm:absolute sm:inset-0 flex justify-center items-center",
      ),
    ],
    [
      case m.image_loaded {
        False ->
          html.div(
            [
              attribute.class(
                "z-20 absolute top-5 sm:right-10 animate-enter-from-top rounded-lg bg-zinc-900 p-4 flex items-center justify-center",
              ),
            ],
            [
              html.i(
                [
                  attribute.class(
                    "animate-spin ph ph-[spinner-ball] text-2xl text-violet-400",
                  ),
                ],
                [],
              ),
            ],
          )
        True -> element.none()
      },
      html.div(
        [attribute.class("flex w-full h-full z-10 absolute top-0 left-0")],
        [
          html.div(
            [attribute.class("flex-1"), event.on_click(model.NavigateLeft)],
            [],
          ),
          html.div(
            [attribute.class("w-[20%]"), event.on_click(model.ToggleMenu)],
            [],
          ),
          html.div(
            [attribute.class("flex-1"), event.on_click(model.NavigateRight)],
            [],
          ),
        ],
      ),
      case m.loading || !m.image_loaded {
        True ->
          html.div(
            [
              attribute.class(
                "absolute inset-0 flex items-center justify-center",
              ),
            ],
            [
              html.i(
                [
                  attribute.class(
                    "ph ph-[spinner-ball] text-4xl animate-spin text-zinc-400",
                  ),
                ],
                [],
              ),
            ],
          )
        False -> element.none()
      },
      html.img([
        attribute.class(image_class),
        attribute.style("transform", scale),
        attribute.id("reader-img"),
        attribute.alt(""),
        attribute.src(page_image_url(progress.page_number)),
        event.on("load", { model.PageLoaded |> decode.success }),
      ]),
      html.div(
        [attribute.class("hidden")],
        list.map(utils.range(1, m.prefs.preload_count), fn(offset) {
          html.img([
            attribute.src(page_image_url(progress.page_number + offset)),
            attribute.alt(""),
            attribute.class("hidden"),
          ])
        }),
      ),
    ],
  )
}
