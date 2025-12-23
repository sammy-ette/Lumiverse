import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import localstorage
import lumiverse/api/stream
import lumiverse/components
import lumiverse/elements/series
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import plinth/javascript/global
import rsvp

type Model {
  Model(
    dashboard_rows: List(stream.SeriesList),
    dashboard_count: Int,
    carousel: option.Option(stream.SeriesList),
    carousel_index: Int,
  )
}

type Msg {
  DashboardRowsRetrieved(Result(List(stream.DashboardRow), rsvp.Error))
  SeriesListRetrieved(Result(stream.SeriesList, rsvp.Error))
  CarouselTick
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
            global.set_interval(2000, fn() { CarouselTick |> dispatch })
            Nil
          }),
          ..list.unique(fetchers)
        ]),
      )
    }
    SeriesListRetrieved(Ok(srs_list)) -> {
      let carousel = case srs_list.title {
        "Recently Updated" -> option.Some(srs_list)
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
        effect.none(),
      )
    }
    CarouselTick -> {
      case m.carousel {
        option.None -> #(m, effect.none())
        option.Some(carousel) -> #(
          Model(
            ..m,
            carousel_index: echo case
              m.carousel_index == list.length(carousel.items) - 1
            {
              True -> 0
              False -> m.carousel_index + 1
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
      html.div([attribute.class("overflow-hidden rounded-md")], [
        html.div(
          [
            attribute.style(
              "transform",
              "translateX(-" <> int.to_string(m.carousel_index * 100) <> "%)",
            ),
            attribute.class(
              "flex h-[45vh] flex-shrink-0 rounded-md bg-sky-800 transition-transform duration-300 ease-in-out",
            ),
          ],
          case m.carousel {
            option.None -> [element.none()]
            option.Some(srs_list) -> carousel(srs_list)
          },
        ),
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

pub fn carousel(srs_list: stream.SeriesList) {
  list.map(srs_list.items, fn(serie) {
    html.div([attribute.class("relative flex w-full h-full flex-shrink-0")], [
      html.div([attribute.class("absolute w-full h-full bg-red-800")], [
        series.cover_image(serie, [
          attribute.class("w-screen object-cover inset-0"),
        ]),
      ]),
      html.div([attribute.class("z-100 flex gap-4 p-8 bg-zinc-950/75")], [
        html.div(
          [attribute.class("rounded-md h-full w-62 flex-shrink-0 bg-white")],
          [],
        ),
        html.div([attribute.class("flex flex-col")], [
          html.h1(
            [
              attribute.class(
                "font-[Poppins,sans-serif] font-extrabold text-4xl",
              ),
            ],
            [element.text(serie.name)],
          ),
          html.div([attribute.class("flex flex-wrap gap-2")], [
            // tag.single("explicit-test-tag"),
          // tag.single("beware-test-tag"),
          // tag.single("Comedy"),
          // tag.single("Romance"),
          ]),
          html.p([attribute.class("flex-wrap text-wrap")], [
            element.text(
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
            ),
          ]),
        ]),
      ]),
    ])
  })
}
