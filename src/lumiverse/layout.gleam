import gleam/option
import lustre/attribute.{attribute}
import lustre/element
import lustre/element/html

import lustre_http as http

import lumiverse/api/msg as api
import lumiverse/components/button.{button}
import lumiverse/config
import lumiverse/model
import lumiverse/models/auth
import lumiverse/models/filter
import lumiverse/models/reader
import lumiverse/models/router
import lumiverse/models/series
import lumiverse/models/stream

// TODO: put messages related to a specific page in separate source
// there is no reason for LoginGot to not be outside auth.Msg
// TODO TODO: handle specific messages where they are declared
pub type Msg {
  Router(router.Msg)
  HealthCheck(Result(Nil, http.HttpError))
  SmartFilterDecode(Result(filter.SmartFilter, http.HttpError))
  //                           \/ represents whether its from dashboard call
  AllSeriesRetrieved(Result(#(Bool, model.SeriesList), http.HttpError))
  //                               \/ series id is not in the response.
  // we need to know it, so its sent back here
  SeriesDetailsRetrieved(Result(#(Int, series.Details), http.HttpError))

  // Auth
  AuthPage(auth.Msg)
  LoginGot(Result(auth.User, http.HttpError))
  RefreshGot(Result(auth.Refresh, http.HttpError))
  ConfigGot(Result(auth.Config, http.HttpError))

  //Home
  DashboardRetrieved(Result(List(stream.DashboardItem), http.HttpError))
  DashboardItemRetrieved(Result(model.SeriesList, http.HttpError))
  SeriesRetrieved(Result(series.MinimalInfo, http.HttpError))
  SeriesMetadataRetrieved(Result(series.Metadata, http.HttpError))

  // Reader
  // if None, read from last chapter
  Read(option.Option(Int))
  ReaderPrevious
  ReaderNext
  ReaderImageLoaded(id: String)
  ProgressUpdated(Result(Nil, http.HttpError))
  ContinuePointRetrieved(Result(reader.ContinuePoint, http.HttpError))
  ProgressRetrieved(Result(reader.Progress, http.HttpError))
  ChapterInfoRetrieved(Result(reader.ChapterInfo, http.HttpError))
  PreviousChapterRetrieved(Result(Int, http.HttpError))
  NextChapterRetrieved(Result(Int, http.HttpError))
}

pub fn nav(model: model.Model) {
  html.nav(
    [
      attribute.class(
        "bg-zinc-950"
        <> case model.route {
          router.Reader(_) -> ""
          _ -> " sticky top-0 left-0 right-0"
        },
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "max-w-screen-xl flex flex-wrap items-center justify-between mx-auto p-4",
          ),
        ],
        [
          html.a(
            [
              attribute.href("/"),
              attribute.class("flex items-center space-x-3"),
            ],
            [
              html.img([attribute.src(config.logo()), attribute.class("h-12")]),
              html.span(
                [
                  attribute.class(
                    "self-center text-2xl font-bold dark:text-white",
                  ),
                ],
                [element.text("Lumiverse")],
              ),
              html.div(
                [
                  attribute.class(
                    "self-center font-bold text-xs rounded py-0.5 px-1 bg-violet-600",
                  ),
                ],
                [element.text("Beta")],
              ),
            ],
          ),
          case model.guest, model.user {
            False, option.Some(user) ->
              html.div([], [
                button([button.md(), attribute.class("text-white")], [
                  element.text(user.username),
                ]),
              ])
            _, _ ->
              html.a([attribute.href("/login")], [
                button([button.solid(button.Neutral), button.md()], [
                  element.text("Login"),
                ]),
              ])
          },
        ],
      ),
    ],
  )
}

fn drop_item(icon: String, name: String, href: String) -> element.Element(a) {
  html.a([attribute.href(href), attribute.class("drop-item")], [
    html.button(
      [attribute.attribute("type", "button"), attribute.class("btn btn-lg")],
      [
        html.span([attribute.class("drop-item-icon icon-" <> icon)], []),
        html.span([attribute.class("drop-item-text")], [element.text(name)]),
      ],
    ),
  ])
}

pub fn footer() -> element.Element(a) {
  html.footer([], [
    html.div([attribute.class("container")], [html.h1([], [element.text("hi")])]),
  ])
}
