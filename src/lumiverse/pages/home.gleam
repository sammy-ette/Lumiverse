import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import localstorage
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
import plinth/javascript/global
import rsvp

type Model {
  Model(
    dashboard_rows: List(stream.SeriesList),
    dashboard_count: Int,
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
  element.element(
    "home-page",
    [attribute.class("flex min-h-screen w-full flex-col py-8 px-4")],
    [],
  )
}

fn init(_) {
  #(
    Model(
      dashboard_rows: [],
      dashboard_count: 0,
      carousel: option.None,
      carousel_index: 0,
      metadata: dict.new(),
    ),
    case localstorage.read("user") {
      Error(_) -> effect.none()
      _ -> stream.dashboard(DashboardRowsRetrieved)
    },
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
              // stream.SmartFilter -> {
              //   let assert option.Some(smart_filter) =
              //     dash_item.smart_filter_encoded
              //   series_req.decode_smart_filter(
              //     user.token,
              //     dash_item.order,
              //     smart_filter,
              //     True,
              //   )
              // }
              _ -> effect.none()
            }
          },
        )

      #(
        Model(
          ..m,
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
            carousel_index: echo case
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
  html.div(
    [
      attribute.class("flex min-h-screen flex-col space-y-8 overflow-hidden"),
      components.redirect_click(Nothing),
    ],
    [
      html.div([attribute.class("space-y-4")], [
        html.h1([attribute.class("font-black text-4xl")], [
          element.text("New On Lumiverse"),
        ]),
        html.div([attribute.class("relative overflow-hidden rounded-md")], [
          html.div(
            [
              attribute.style(
                "transform",
                "translateX(-" <> int.to_string(m.carousel_index * 100) <> "%)",
              ),
              attribute.class(
                "flex h-[45vh] flex-shrink-0 rounded-md bg-zinc-800 transition-transform duration-300 ease-in-out",
              ),
            ],
            case m.carousel {
              option.None -> [element.none()]
              option.Some(srs_list) -> carousel(m, srs_list)
            },
          ),
          html.div([attribute.class("absolute bottom-8 right-8 flex gap-4")], [
            button.button([event.on_click(CarouselTick(-1))], [
              html.i([attribute.class("ph ph-caret-left text-2xl")], []),
            ]),
            button.button([event.on_click(CarouselTick(1))], [
              html.i([attribute.class("ph ph-caret-right text-2xl")], []),
            ]),
          ]),
        ]),
      ]),
      html.div(
        [attribute.class("space-y-5")],
        list.take(
          list.flatten([
            list.map(m.dashboard_rows, fn(row) {
              html.div([attribute.class("flex flex-col gap-3")], [
                html.h2([attribute.class("font-extrabold text-3xl")], [
                  element.text(row.title),
                ]),
                html.div(
                  [attribute.class("flex gap-4 overflow-x-auto")],
                  list.map(row.items, series.card),
                ),
              ])
            }),
            list.repeat(
              html.div([attribute.class("flex flex-col gap-3")], [
                html.h2(
                  [
                    attribute.class(
                      "font-extrabold text-3xl animate-pulse bg-zinc-800 h-10 w-52",
                    ),
                  ],
                  [],
                ),
                html.div(
                  [attribute.class("flex gap-4 overflow-x-auto")],
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

fn carousel(m: Model, srs_list: stream.SeriesList) {
  list.map(srs_list.items, fn(serie) {
    html.a(
      [
        attribute.href("/series/" <> serie.id |> int.to_string),
        attribute.class("relative flex w-full h-full flex-shrink-0"),
      ],
      [
        html.div([attribute.class("absolute w-full h-full bg-zinc-800")], [
          series.cover_image(serie, [
            attribute.class("w-screen object-cover inset-0"),
          ]),
        ]),
        html.div(
          [attribute.class("z-100 flex gap-4 p-8 bg-zinc-950/75 w-full")],
          [
            html.div(
              [
                attribute.class(
                  "overflow-hidden rounded-md h-full w-62 flex-shrink-0 bg-white",
                ),
              ],
              [series.cover_image(serie, [attribute.class("object-cover")])],
            ),
            html.div([attribute.class("flex flex-col gap-2")], [
              html.h1(
                [
                  attribute.class(
                    "font-[Poppins,sans-serif] font-extrabold text-4xl",
                  ),
                ],
                [element.text(serie.name)],
              ),
              {
                use metadata <- result.try(
                  m.metadata
                  |> dict.get(serie.id)
                  |> result.replace_error(element.none()),
                )

                html.div(
                  [attribute.class("flex-1 flex flex-col justify-between")],
                  [
                    html.div([attribute.class("flex flex-col gap-2")], [
                      tag.list(metadata.tags),
                      html.p([attribute.class("flex-wrap text-wrap")], [
                        element.text(metadata.summary),
                      ]),
                    ]),
                    // html.div([attribute.class("flex")], [element.text("Author Name")]),
                  ],
                )
                |> Ok
              }
                |> result.unwrap_both,
            ]),
          ],
        ),
      ],
    )
  })
}
