import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import lumiverse/api/series as series_api
import lumiverse/api/stream
import lumiverse/components
import lumiverse/elements/button
import lumiverse/elements/series
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import plinth/browser/document
import plinth/javascript/global
import rsvp

type Model {
  Model(
    dashboard_rows: List(stream.SeriesList),
    dashboard_count: Int,
    loaded: Bool,
    carousel: option.Option(stream.SeriesList),
    carousel_index: Int,
    metadata: dict.Dict(Int, series_api.Metadata),
  )
}

type Msg {
  DashboardRowsRetrieved(Result(List(stream.DashboardRow), rsvp.Error))
  SeriesListRetrieved(Result(stream.SeriesList, rsvp.Error))
  MetadataRetrieved(Result(series_api.Metadata, rsvp.Error))
  CarouselTick(Int)
  Nothing
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "home-page")
}

pub fn element() {
  document.set_title("Lumiverse")
  element.element(
    "home-page",
    [attribute.class("flex min-h-screen w-full flex-col py-8 px-4 pt-0")],
    [],
  )
}

fn init(_) {
  #(
    Model(
      dashboard_rows: [],
      dashboard_count: 0,
      loaded: False,
      carousel: option.None,
      carousel_index: 0,
      metadata: dict.new(),
    ),
    stream.dashboard(DashboardRowsRetrieved),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    DashboardRowsRetrieved(Ok(rows)) -> {
      let fetchers =
        list.map(
          list.filter(rows, fn(itm) { itm.visible }),
          fn(dash_item: stream.DashboardRow) {
            case dash_item.stream_type {
              stream.OnDeck ->
                stream.on_deck(dash_item.order, SeriesListRetrieved)
              stream.RecentlyUpdated ->
                stream.recently_updated(dash_item.order, SeriesListRetrieved)
              stream.NewlyAdded ->
                stream.recently_added(dash_item.order, SeriesListRetrieved)
              _ -> effect.none()
            }
          },
        )

      #(
        Model(
          ..m,
          loaded: True,
          dashboard_count: list.length(
            list.filter(rows, fn(itm) {
              bool.and(itm.visible, case itm.stream_type {
                stream.MoreInGenre -> False
                _ -> True
              })
            }),
          ),
        ),
        effect.batch([
          effect.from(fn(dispatch) {
            global.set_interval(5000, fn() { CarouselTick(1) |> dispatch })
            Nil
          }),
          ..list.unique(fetchers)
        ]),
      )
    }
    SeriesListRetrieved(Ok(srs_list)) -> {
      let carousel = case srs_list.title {
        "Newly Added" -> option.Some(srs_list)
        _ -> m.carousel
      }
      #(
        Model(
          ..m,
          dashboard_rows: case list.length(srs_list.items) {
            0 -> m.dashboard_rows
            _ ->
              list.sort([srs_list, ..m.dashboard_rows], fn(a, b) {
                int.compare(a.idx, b.idx)
              })
          },
          dashboard_count: case list.length(srs_list.items) {
            0 -> m.dashboard_count - 1
            _ -> m.dashboard_count
          },
          carousel:,
        ),
        case srs_list.title {
          "Newly Added" ->
            effect.batch(
              list.map(srs_list.items, fn(serie) {
                series_api.metadata(serie.id, MetadataRetrieved)
              }),
            )
          _ -> effect.none()
        },
      )
    }
    MetadataRetrieved(Ok(metadata)) -> {
      #(
        Model(..m, metadata: m.metadata |> dict.insert(metadata.id, metadata)),
        effect.none(),
      )
    }
    CarouselTick(offset) -> {
      case m.carousel {
        option.None -> #(m, effect.none())
        option.Some(carousel) -> #(
          Model(
            ..m,
            carousel_index: case
              m.carousel_index == list.length(carousel.items) - 1
            {
              True -> 0
              False -> m.carousel_index + offset
            },
          ),
          effect.none(),
        )
      }
    }
    _ -> #(m, effect.none())
  }
}

fn view(m: Model) {
  case m.loaded, m.dashboard_rows, m.dashboard_count {
    True, [], 0 -> element.none()
    _, _, _ ->
      html.div(
        [
          attribute.class("flex min-h-screen flex-col space-y-10"),
          components.redirect_click(Nothing),
        ],
        [
          html.div([attribute.class("relative overflow-hidden -mx-4")], [
            html.div(
              [
                attribute.style(
                  "transform",
                  "translateX(-"
                    <> int.to_string(m.carousel_index * 100)
                    <> "%)",
                ),
                attribute.class(
                  "flex h-[26vh] sm:h-[40vh] flex-shrink-0 bg-zinc-800 transition-transform duration-300 ease-in-out",
                ),
              ],
              case m.carousel {
                option.None -> [element.none()]
                option.Some(srs_list) -> carousel(m, srs_list)
              },
            ),
            html.div(
              [
                attribute.class(
                  "absolute bottom-6 sm:bottom-8 left-1/2 -translate-x-1/2 flex gap-2 z-20",
                ),
              ],
              case m.carousel {
                option.None -> []
                option.Some(srs_list) ->
                  list.index_map(srs_list.items, fn(_, idx) {
                    html.div(
                      [
                        attribute.class(
                          "h-1.5 rounded-full transition-all duration-300 "
                          <> case idx == m.carousel_index {
                            True -> "w-6 bg-white"
                            False -> "w-1.5 bg-white/40"
                          },
                        ),
                      ],
                      [],
                    )
                  })
              },
            ),
            html.div(
              [
                attribute.class(
                  "absolute bottom-6 sm:bottom-8 right-4 sm:right-8 flex gap-3 z-20",
                ),
              ],
              [
                button.icon("ph ph-caret-left text-xl", [
                  event.on_click(CarouselTick(-1)),
                  attribute.class(
                    "rounded-full bg-zinc-950/60 backdrop-blur-sm p-2 hover:bg-zinc-800/70",
                  ),
                ]),
                button.icon("ph ph-caret-right text-xl", [
                  event.on_click(CarouselTick(1)),
                  attribute.class(
                    "rounded-full bg-zinc-950/60 backdrop-blur-sm p-2 hover:bg-zinc-800/70",
                  ),
                ]),
              ],
            ),
          ]),
          html.div(
            [attribute.class("space-y-8")],
            list.take(
              list.flatten([
                list.map(m.dashboard_rows, fn(row) {
                  html.div([attribute.class("flex flex-col gap-3")], [
                    html.div(
                      [attribute.class("flex items-center justify-between")],
                      [
                        html.div([attribute.class("flex items-center gap-3")], [
                          html.div(
                            [
                              attribute.class(
                                "w-1 self-stretch bg-violet-500 rounded-full",
                              ),
                            ],
                            [],
                          ),
                          html.h2([attribute.class("font-extrabold text-2xl")], [
                            element.text(row.title),
                          ]),
                        ]),
                        // html.a(
                      //   [
                      //     attribute.href("/search"),
                      //     attribute.class(
                      //       "text-sm text-zinc-500 hover:text-violet-400 transition-colors shrink-0",
                      //     ),
                      //   ],
                      //   [element.text("See all →")],
                      // ),
                      ],
                    ),
                    html.div(
                      [
                        attribute.class(
                          "flex gap-4 overflow-x-auto snap-x snap-mandatory pb-1",
                        ),
                      ],
                      list.map(row.items, series.card),
                    ),
                  ])
                }),
                list.repeat(
                  html.div([attribute.class("flex flex-col gap-3")], [
                    html.div(
                      [attribute.class("flex items-center justify-between")],
                      [
                        html.div([attribute.class("flex items-center gap-3")], [
                          html.div(
                            [
                              attribute.class(
                                "w-1 h-8 bg-zinc-800 rounded-full animate-pulse",
                              ),
                            ],
                            [],
                          ),
                          html.h2(
                            [
                              attribute.class(
                                "font-extrabold text-2xl animate-pulse bg-zinc-800 h-8 w-48",
                              ),
                            ],
                            [],
                          ),
                        ]),
                        // html.div(
                        //   [attribute.class("w-14 h-4 bg-zinc-800 rounded animate-pulse")],
                        //   [],
                        // ),
                        element.none(),
                      ],
                    ),
                    html.div(
                      [
                        attribute.class(
                          "flex gap-4 overflow-x-auto snap-x snap-mandatory pb-1",
                        ),
                      ],
                      list.repeat(series.card_placeholder(), 5),
                    ),
                  ]),
                  m.dashboard_count,
                ),
              ]),
              m.dashboard_count,
            ),
          ),
        ],
      )
  }
}

fn carousel(m: Model, srs_list: stream.SeriesList) {
  list.map(srs_list.items, fn(serie) {
    let metadata = dict.get(m.metadata, serie.id)
    html.a(
      [
        attribute.href("/series/" <> serie.id |> int.to_string),
        attribute.class("relative flex w-full h-full flex-shrink-0"),
      ],
      [
        // Full-bleed background image
        html.div([attribute.class("absolute inset-0 bg-zinc-800")], [
          series.cover_image(serie, [
            attribute.class("w-full h-full object-cover"),
          ]),
        ]),
        // Mobile: top-anchored cover + text
        html.div(
          [
            attribute.class(
              "sm:hidden absolute inset-0 z-10 flex items-start gap-3 p-4 bg-zinc-950/75 backdrop-blur-sm",
            ),
          ],
          [
            series.cover_image(serie, [
              attribute.class(
                "bg-zinc-800 rounded-lg w-24 h-36 object-cover flex-shrink-0",
              ),
            ]),
            html.div([attribute.class("flex flex-col gap-2 min-w-0 pt-1")], [
              html.h1(
                [
                  attribute.class(
                    "font-extrabold text-xl line-clamp-3 leading-tight",
                  ),
                ],
                [element.text(serie.name)],
              ),
              case metadata {
                Error(_) -> element.none()
                Ok(meta) ->
                  html.div([attribute.class("flex flex-wrap gap-1")], [
                    tag.list(list.take(meta.tags, 4)),
                  ])
              },
              html.span(
                [
                  attribute.class(
                    "inline-flex w-fit items-center px-3 py-1.5 rounded-lg bg-violet-500 text-white text-xs font-semibold",
                  ),
                ],
                [element.text("Read Now →")],
              ),
            ]),
          ],
        ),
        // Desktop: side-by-side layout
        html.div(
          [
            attribute.class(
              "hidden sm:flex z-10 gap-6 p-8 bg-zinc-950/75 backdrop-blur-sm w-full",
            ),
          ],
          [
            series.cover_image(serie, [
              attribute.class(
                "bg-zinc-800 rounded-lg h-72 w-48 object-cover flex-shrink-0 shadow-2xl shadow-zinc-950",
              ),
            ]),
            html.div([attribute.class("flex flex-col gap-2 min-w-0 flex-1")], [
              html.h1([attribute.class("font-extrabold text-5xl")], [
                element.text(serie.name),
              ]),
              case metadata {
                Error(_) -> element.none()
                Ok(meta) ->
                  html.div(
                    [attribute.class("flex flex-col gap-2 overflow-hidden")],
                    [
                      html.div([attribute.class("flex flex-wrap gap-1")], [
                        tag.list(meta.tags),
                      ]),
                      html.p(
                        [
                          attribute.class(
                            "text-wrap line-clamp-3 text-sm text-zinc-300",
                          ),
                        ],
                        [element.text(meta.summary)],
                      ),
                      html.span(
                        [
                          attribute.class(
                            "inline-flex w-fit items-center gap-1.5 px-4 py-2 rounded-lg bg-violet-500 text-white text-sm font-semibold",
                          ),
                        ],
                        [element.text("Read Now →")],
                      ),
                    ],
                  )
              },
            ]),
          ],
        ),
      ],
    )
  })
}
