import gleam/bool
import gleam/int
import gleam/list
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
import rsvp

type Model {
  Model(dashboard_rows: List(stream.SeriesList), dashboard_count: Int)
}

type Msg {
  DashboardRowsRetrieved(Result(List(stream.DashboardRow), rsvp.Error))
  SeriesListRetrieved(Result(stream.SeriesList, rsvp.Error))
  Nothing
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "home-page")
}

pub fn element() {
  element.element(
    "home-page",
    [attribute.class("flex-1 flex flex-col p-4")],
    [],
  )
}

fn init(_) {
  #(
    Model(dashboard_rows: [], dashboard_count: 0),
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
        effect.batch(list.unique(fetchers)),
      )
    }
    SeriesListRetrieved(Ok(srs_list)) -> #(
      Model(
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
      ),
      effect.none(),
    )
    _ -> #(m, effect.none())
  }
}

fn view(m: Model) {
  html.div([attribute.class("space-y-8"), components.redirect_click(Nothing)], [
    html.div(
      [attribute.class("h-1/3 min-h-48 bg-sky-500 rounded-md p-4 flex gap-4")],
      [
        html.div([attribute.class("rounded-md h-full w-42 bg-white")], []),
        html.div([attribute.class("flex flex-col gap-2")], [
          html.h1(
            [attribute.class("font-[Poppins,sans-serif] font-bold text-2xl")],
            [element.text("Insert A Manga Name Here")],
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
      ],
    ),
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
  ])
}
