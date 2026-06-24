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
    carousel_control_clicked: Bool,
    carousel_index: Int,
    metadata: dict.Dict(Int, series_api.Metadata),
  )
}

type Msg {
  DashboardRowsRetrieved(Result(List(stream.DashboardRow), rsvp.Error))
  SeriesListRetrieved(Result(stream.SeriesList, rsvp.Error))
  MetadataRetrieved(Result(series_api.Metadata, rsvp.Error))
  CarouselTick(Int)
  CarouselPrev
  CarouselNext
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
    [attribute.class("flex flex-col min-h-screen w-full p-8")],
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
      carousel_control_clicked: False,
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
          dashboard_rows: case list.is_empty(srs_list.items) {
            True -> m.dashboard_rows
            False ->
              list.sort([srs_list, ..m.dashboard_rows], fn(a, b) {
                int.compare(a.idx, b.idx)
              })
          },
          dashboard_count: case list.is_empty(srs_list.items) {
            True -> m.dashboard_count - 1
            False -> m.dashboard_count
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
      case m.carousel, m.carousel_control_clicked {
        option.None, _ -> #(m, effect.none())
        option.Some(_), True -> #(
          Model(..m, carousel_control_clicked: False),
          effect.none(),
        )
        option.Some(carousel), False -> #(
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
    CarouselPrev ->
      case m.carousel {
        option.None -> #(m, effect.none())
        option.Some(carousel) -> #(
          Model(
            ..m,
            carousel_control_clicked: True,
            carousel_index: case echo m.carousel_index == 0 {
              True -> list.length(carousel.items) - 1
              False -> m.carousel_index - 1
            },
          ),
          effect.none(),
        )
      }
    CarouselNext ->
      case m.carousel {
        option.None -> #(m, effect.none())
        option.Some(carousel) -> #(
          Model(
            ..m,
            carousel_control_clicked: True,
            carousel_index: case
              m.carousel_index == list.length(carousel.items) - 1
            {
              True -> 0
              False -> m.carousel_index + 1
            },
          ),
          effect.none(),
        )
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
          attribute.class("flex min-h-screen flex-col gap-10"),
          components.redirect_click(Nothing),
        ],
        [
          carousel_element(m),
          html.div(
            [attribute.class("space-y-8")],
            list.take(
              list.flatten([
                list.map(m.dashboard_rows, fn(row) {
                  html.div([attribute.class("flex flex-col gap-3")], [
                    html.div([attribute.class("flex items-center gap-3")], [
                      html.h2(
                        [
                          attribute.class(
                            "font-[DM_Serif_Display,serif] font-bold text-2xl",
                          ),
                        ],
                        [
                          element.text(row.title),
                        ],
                      ),
                      html.div(
                        [
                          attribute.class(
                            "flex-1 h-px border-t border-zinc-700",
                          ),
                        ],
                        [],
                      ),
                    ]),
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
                    html.div([attribute.class("flex items-center gap-3")], [
                      html.h2(
                        [
                          attribute.class(
                            "h-8 w-48 bg-zinc-800 rounded animate-pulse",
                          ),
                        ],
                        [],
                      ),
                      html.div(
                        [
                          attribute.class(
                            "flex-1 h-px border-t border-zinc-700",
                          ),
                        ],
                        [],
                      ),
                    ]),
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

fn carousel_element(m: Model) {
  html.div([attribute.class("relative overflow-hidden rounded-xl")], [
    html.div(
      [
        attribute.style(
          "transform",
          "translateX(-" <> int.to_string(m.carousel_index * 100) <> "%)",
        ),
        attribute.class(
          "flex flex-shrink-0 bg-zinc-800 transition-transform duration-400 ease-in-out",
        ),
      ],
      case m.carousel {
        option.None -> [carousel_skeleton()]
        option.Some(srs_list) -> carousel(m, srs_list)
      },
    ),
    case m.carousel {
      option.None -> element.none()
      option.Some(srs_list) ->
        html.div(
          [
            attribute.class(
              "absolute inset-x-4 bottom-4 sm:bottom-8 z-20 flex h-9 items-center justify-center",
            ),
          ],
          [
            html.div(
              [attribute.class("flex items-center gap-2")],
              list.index_map(srs_list.items, fn(_, idx) {
                html.div(
                  [
                    attribute.class(
                      "h-1.5 rounded-full transition-all duration-300",
                    ),
                    case idx == m.carousel_index {
                      True -> attribute.class("w-6 bg-white")
                      False -> attribute.class("w-1.5 bg-white/40")
                    },
                  ],
                  [],
                )
              }),
            ),
            html.div(
              [
                attribute.class(
                  "absolute inset-y-0 right-0 flex items-center gap-3",
                ),
              ],
              [
                button.icon("ph ph-[caret-left] text-xl", "Previous", [
                  event.on_click(CarouselPrev),
                  attribute.class(
                    "rounded-full bg-zinc-950/60 backdrop-blur-sm p-2 hover:bg-zinc-800/70",
                  ),
                ]),
                button.icon("ph ph-[caret-right] text-xl", "Next", [
                  event.on_click(CarouselNext),
                  attribute.class(
                    "rounded-full bg-zinc-950/60 backdrop-blur-sm p-2 hover:bg-zinc-800/70",
                  ),
                ]),
              ],
            ),
          ],
        )
    },
  ])
}

fn carousel_skeleton() -> element.Element(Msg) {
  html.div([attribute.class("relative flex w-full flex-shrink-0")], [
    html.div(
      [attribute.class("absolute inset-0 bg-zinc-800 animate-pulse")],
      [],
    ),
    html.div(
      [
        attribute.class(
          "relative z-10 flex w-full items-stretch gap-3 px-4 py-14 sm:gap-6 sm:px-8 sm:py-8 bg-zinc-950/75 backdrop-blur-sm",
        ),
      ],
      [
        html.div(
          [
            attribute.class(
              "flex-shrink-0 rounded-lg bg-zinc-700 animate-pulse w-24 h-36 sm:w-48 sm:h-72",
            ),
          ],
          [],
        ),
        html.div(
          [
            attribute.class(
              "flex flex-col justify-between gap-2 min-w-0 flex-1",
            ),
          ],
          [
            html.div([attribute.class("flex flex-col gap-2")], [
              html.div([attribute.class("flex flex-col gap-2 sm:gap-3")], [
                html.div(
                  [
                    attribute.class(
                      "h-7 sm:h-12 w-full bg-zinc-700 rounded animate-pulse",
                    ),
                  ],
                  [],
                ),
                html.div(
                  [attribute.class("flex flex-wrap gap-1")],
                  list.map(
                    [
                      "h-5 w-14 bg-zinc-700 rounded-full animate-pulse",
                      "h-5 w-20 bg-zinc-700 rounded-full animate-pulse",
                      "h-5 w-16 bg-zinc-700 rounded-full animate-pulse",
                    ],
                    fn(c) { html.div([attribute.class(c)], []) },
                  ),
                ),
                html.div(
                  [
                    attribute.class(
                      "h-7 sm:h-12 w-1/2 bg-zinc-700 rounded animate-pulse",
                    ),
                  ],
                  [],
                ),
              ]),
            ]),
            html.div(
              [attribute.class("h-9 w-32 bg-zinc-700 rounded-lg animate-pulse")],
              [],
            ),
          ],
        ),
      ],
    ),
  ])
}

fn carousel(m: Model, srs_list: stream.SeriesList) {
  list.index_map(srs_list.items, fn(serie, idx) {
    let metadata = dict.get(m.metadata, serie.id)
    let priority_attrs = case idx == m.carousel_index {
      True -> [attribute.attribute("fetchpriority", "high")]
      False -> [attribute.attribute("loading", "lazy")]
    }
    html.a(
      [
        attribute.href("/series/" <> serie.id |> int.to_string),
        attribute.class("relative flex w-full flex-shrink-0"),
      ],
      [
        // blurred cover fills the slide as a backdrop (out of flow)
        html.div([attribute.class("absolute inset-0 bg-zinc-800")], [
          series.cover_image_w(serie, 800, [
            attribute.class("w-full h-full object-cover"),
            ..priority_attrs
          ]),
        ]),
        // content panel stays in flow so it gives the slide its height
        html.div(
          [
            attribute.class(
              "relative z-10 flex w-full items-stretch gap-3 px-4 py-14 sm:gap-6 sm:px-8 sm:py-8 bg-zinc-950/75 backdrop-blur-sm",
            ),
          ],
          [
            series.cover_image(serie, [
              attribute.class(
                "flex-shrink-0 rounded-lg object-cover bg-zinc-800 w-24 h-36 sm:w-48 sm:h-72 sm:shadow-2xl sm:shadow-zinc-950",
              ),
              ..priority_attrs
            ]),
            html.div(
              [
                attribute.class(
                  "flex flex-col justify-between gap-2 min-w-0 flex-1",
                ),
              ],
              [
                html.div([attribute.class("flex flex-col gap-2")], [
                  html.h1(
                    [
                      attribute.class(
                        "font-extrabold text-xl sm:text-5xl line-clamp-3 leading-tight",
                      ),
                    ],
                    [element.text(serie.name)],
                  ),
                  case metadata {
                    Error(_) -> element.none()
                    Ok(meta) ->
                      html.div(
                        [attribute.class("flex flex-col gap-3 overflow-hidden")],
                        [
                          html.div(
                            [
                              attribute.class(
                                "flex flex-wrap gap-1 overflow-hidden max-h-14 sm:max-h-none",
                              ),
                            ],
                            [
                              tag.list(
                                meta.tags
                                |> list.append(meta.genres)
                                |> tag.sort,
                              ),
                            ],
                          ),
                          html.p(
                            [
                              attribute.class(
                                "hidden sm:line-clamp-3 text-sm text-zinc-300",
                              ),
                            ],
                            [element.text(meta.summary)],
                          ),
                        ],
                      )
                  },
                ]),
                button.button("Read Now", [
                  attribute.class("w-fit"),
                  button.primary(),
                ]),
              ],
            ),
          ],
        ),
      ],
    )
  })
}
