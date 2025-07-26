import gleam/dict
import gleam/int
import gleam/list
import gleam/option

import lustre/attribute.{attribute}
import lustre/element
import lustre/element/html

import lumiverse/elements/series
import lumiverse/elements/tag
import lumiverse/layout
import lumiverse/model
import lumiverse/models/auth as auth_model
import lumiverse/models/series as series_model
import router

pub fn page(model: model.Model) -> element.Element(layout.Msg) {
  html.div([], case model.user {
    option.None -> []
    option.Some(user) -> {
      [
        //html.div([attribute.id("featuredCarousel"), attribute.class("featured-carousel carousel container slide"), attribute.attribute("data-bs-ride", "carousel")], [
        //	html.h1([], [element.text("Newest Series")]),
        //	html.div([attribute.class("carousel-inner")], [
        //		{
        //			let assert Ok(srs) = list.first(model.home.carousel_smalldata)
        //			carousel_item(model, user, srs, True)
        //		},
        //		..list.append(
        //			list.map(list.drop(model.home.carousel_smalldata, 1), fn(srs: series_model.MinimalInfo) -> element.Element(layout.Msg) {
        //				carousel_item(model, user, srs, False)
        //			}),
        //			[
        //				html.div([attribute.class("featured-carousel-controls")], [
        //					html.button([attribute.class("carousel-control-prev"), attribute.attribute("data-bs-target", "#featuredCarousel"), attribute.attribute("data-bs-slide", "prev")], [
        //						html.span([attribute.class("icon-angle-left")], []),
        //					]),
        //					html.button([attribute.class("carousel-control-next"), attribute.attribute("data-bs-target", "#featuredCarousel"), attribute.attribute("data-bs-slide", "next")], [
        //						html.span([attribute.class("icon-angle-right")], []),
        //					])
        //				])
        //			]
        //		)
        //	])
        //]),
        html.div(
          [
            attribute.class(
              "max-w-screen-xl flex flex-nowrap flex-col mx-auto mb-8 px-4 space-y-5",
            ),
          ],
          list.take(
            list.flatten([
              list.map(model.home.series_lists, fn(serie_list) {
                series.series_list(
                  list.map(serie_list.items, fn(serie) {
                    series.card(model, serie)
                  }),
                  serie_list.title,
                )
              }),
              list.repeat(
                series.placeholder_series_list(),
                model.home.dashboard_count,
              ),
            ]),
            model.home.dashboard_count,
          ),
        ),
      ]
    }
  })
}

fn carousel_item(
  model: model.Model,
  user: auth_model.User,
  srs: series_model.MinimalInfo,
  active: Bool,
) {
  let active_string = case active {
    True -> " active"
    False -> ""
  }
  let cover_url =
    router.direct(
      "/api/image/series-cover?seriesId="
      <> int.to_string(srs.id)
      <> "&apiKey="
      <> user.api_key,
    )
  let assert Ok(metadata): Result(series_model.Metadata, Nil) =
    dict.get(model.metadatas, srs.id)

  html.div([attribute.class("carousel-item" <> active_string)], [
    html.a(
      [
        attribute.class("text-reset carousel-content"),
        attribute.href("/series/" <> int.to_string(srs.id)),
      ],
      [
        html.div(
          [
            attribute.class("series-bg-image bg-image-backdrop"),
            attribute.style("background-image", "url(" <> cover_url <> ")"),
            attribute.style("height", "28.8rem"),
          ],
          [],
        ),
        html.div(
          [
            attribute.class("series-bg-image bg-image-backdrop"),
            attribute.style(
              "background",
              "linear-gradient(to bottom,rgb(var(--background-primary-rgb), .6),rgb(var(--background-primary-rgb)))",
            ),
            attribute.style("height", "28.8rem"),
          ],
          [],
        ),
        html.div([attribute.class("item-detail row")], [
          html.div([attribute.class("col-4")], [
            html.img([
              attribute.src(cover_url),
              attribute.class("rounded"),
              attribute.style("max-height", "20rem"),
            ]),
          ]),
          html.div([attribute.class("item-text col")], [
            html.h2([], [element.text(srs.name)]),
            tag.list(list.append(
              list.map(metadata.tags, fn(t) { t.title }),
              list.map(metadata.genres, fn(t) { t.title }),
            )),
            html.p([], [element.text(metadata.summary)]),
          ]),
        ]),
      ],
    ),
  ])
}
