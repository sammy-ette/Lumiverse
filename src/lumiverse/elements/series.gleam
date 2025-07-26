import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element
import lustre/element/html

import lumiverse/layout
import lumiverse/model
import lumiverse/models/series
import router

pub fn series_list(serieslist: List(element.Element(layout.Msg)), title: String) {
  html.div([attribute.class("space-y-3")], [
    html.h1(
      [
        attribute.class(
          "text-lg sm:text-3xl font-bold sm:font-extrabold font-['Poppins']",
        ),
      ],
      [element.text(title)],
    ),
    html.div(
      [
        attribute.class(
          "flex flex-nowrap space-x-5 w-full flex gap-4 snap-x snap-mandatory overflow-x-auto",
        ),
      ],
      serieslist,
    ),
  ])
}

pub fn placeholder_series_list() {
  series_list(list.repeat(placeholder_card(), 5), "")
}

pub fn card(
  model: model.Model,
  srs: series.MinimalInfo,
) -> element.Element(layout.Msg) {
  let assert option.Some(user) = model.user
  let cover_url =
    router.direct(
      "/api/image/series-cover?seriesId="
      <> int.to_string(srs.id)
      <> "&apiKey="
      <> user.api_key,
    )

  html.a([attribute.href("/series/" <> int.to_string(srs.id))], [
    html.div([attribute.class("snap-start sm:w-48 w-24 space-y-2")], [
      html.img([
        attribute.attribute("loading", "lazy"),
        attribute.src(cover_url),
        attribute.class("rounded bg-zinc-800 w-full object-cover sm:h-72 h-44"),
      ]),
      html.div([attribute.class("font-medium text-xs md:text-base")], [
        element.text(srs.name),
      ]),
    ]),
  ])
}

pub fn placeholder_card() {
  html.div([attribute.class("space-y-4")], [
    html.div(
      [
        attribute.class(
          "animate-pulse rounded-lg bg-zinc-800 sm:w-48 w-24 h-72",
        ),
      ],
      [],
    ),
    html.div(
      [attribute.class("animate-pulse rounded-none bg-zinc-800 w-full h-4")],
      [],
    ),
    html.div(
      [attribute.class("animate-pulse rounded-none bg-zinc-800 w-1/2 h-4")],
      [],
    ),
  ])
}
