import gleam/dynamic/decode
import gleam/list
import lumiverse/api/reader
import lumiverse/pages/reader/model
import lumiverse/pages/reader/utils
import lustre/attribute
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
    list.map(utils.range(0, m.strip_loaded), fn(i) {
      html.img([
        attribute.src(page_image_url(i)),
        attribute.loading("lazy"),
        attribute.class(image_class),
      ])
    }),
  )
}
