import gleam/dynamic/decode
import gleam/int
import gleam/option
import lumiverse/models/reader as reader_model
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre_http

import lumiverse/api/reader

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_property_change("series-id", {
        decode.int |> decode.map(SeriesID)
      }),
    ])
  lustre.register(app, "reader-page")
}

pub fn element() {
  element.element(
    "reader-page",
    [
      attribute.class("items-center justify-between"),
      attribute.id("reader-page"),
      attribute.style("position", "relative"),
    ],
    [],
  )
}

pub type Model {
  Model(continue_point: option.Option(reader_model.ContinuePoint))
}

pub type Msg {
  SeriesID(Int)
  ContinuePointRetrieved(
    Result(reader_model.ContinuePoint, lustre_http.HttpError),
  )
}

pub fn init(_) {
  #(Model(continue_point: option.None), effect.none())
}

pub fn update(m: Model, msg: Msg) {
  case msg {
    SeriesID(id) -> #(m, reader.continue_point("", id, ContinuePointRetrieved))
    ContinuePointRetrieved(Ok(cont_point)) -> #(
      Model(..m, continue_point: option.Some(cont_point)),
      effect.none(),
    )
    ContinuePointRetrieved(Error(_)) -> #(m, effect.none())
  }
}

pub fn view(m: Model) {
  html.div([], [])
}
