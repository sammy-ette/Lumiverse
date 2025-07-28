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
