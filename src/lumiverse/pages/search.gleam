import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import lumiverse/api/search
import lumiverse/api/series
import lumiverse/elements/series as series_el
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import plinth/browser/document
import plinth/javascript/date
import rsvp

type Model {
  Model(
    query: String,
    results: List(search.SeriesSearchResult),
    metadata: dict.Dict(Int, series.Metadata),
    active_tags: List(Int),
    active_age_rating: option.Option(series.AgeRating),
    loading: Bool,
    pending_metadata: Int,
  )
}

type Msg {
  QueryChanged(String)
  GotResults(Result(List(search.SeriesSearchResult), rsvp.Error))
  GotMetadata(Int, Result(series.Metadata, rsvp.Error))
  ToggleTag(Int)
  SetAgeRating(option.Option(series.AgeRating))
}

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("query", fn(value) {
        Ok(QueryChanged(value))
      }),
    ])
  lustre.register(app, "search-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "search-page",
    [attribute.class("flex w-full flex-col p-4"), ..attrs],
    [],
  )
}

pub fn query(q: String) {
  attribute.attribute("query", q)
}

fn init(_) {
  #(
    Model(
      query: "",
      results: [],
      metadata: dict.new(),
      active_tags: [],
      active_age_rating: option.None,
      loading: False,
      pending_metadata: 0,
    ),
    effect.none(),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    QueryChanged(q) ->
      case string.is_empty(q) {
        True -> #(
          Model(
            query: q,
            results: [],
            metadata: dict.new(),
            active_tags: [],
            active_age_rating: option.None,
            loading: False,
            pending_metadata: 0,
          ),
          effect.none(),
        )
        False -> #(
          Model(
            query: q,
            results: [],
            metadata: dict.new(),
            active_tags: [],
            active_age_rating: option.None,
            loading: True,
            pending_metadata: 0,
          ),
          search.search(q, GotResults),
        )
      }

    GotResults(Ok(results)) -> {
      document.set_title("Search: " <> m.query <> " | Lumiverse")
      let effects =
        list.map(results, fn(r) {
          series.metadata(r.series_id, fn(res) { GotMetadata(r.series_id, res) })
        })
      #(
        Model(..m, results:, loading: False, pending_metadata: list.length(results)),
        effect.batch(effects),
      )
    }

    GotResults(Error(_)) -> #(
      Model(..m, results: [], loading: False, pending_metadata: 0),
      effect.none(),
    )

    GotMetadata(id, Ok(meta)) -> #(
      Model(
        ..m,
        metadata: dict.insert(m.metadata, id, meta),
        pending_metadata: m.pending_metadata - 1,
      ),
      effect.none(),
    )

    GotMetadata(_, Error(_)) -> #(
      Model(..m, pending_metadata: m.pending_metadata - 1),
      effect.none(),
    )

    ToggleTag(id) -> {
      let active_tags = case list.contains(m.active_tags, id) {
        True -> list.filter(m.active_tags, fn(t) { t != id })
        False -> [id, ..m.active_tags]
      }
      #(Model(..m, active_tags:), effect.none())
    }

    SetAgeRating(rating) -> #(
      Model(..m, active_age_rating: rating),
      effect.none(),
    )
  }
}

fn filtered_results(m: Model) -> List(search.SeriesSearchResult) {
  list.filter(m.results, fn(r) {
    case dict.get(m.metadata, r.series_id) {
      Error(_) -> True
      Ok(meta) -> {
        let tag_ok = case m.active_tags {
          [] -> True
          tags ->
            list.any(tags, fn(tid) {
              list.any(meta.tags, fn(t) { t.id == tid })
            })
        }
        let rating_ok = case m.active_age_rating {
          option.None -> True
          option.Some(rating) -> meta.age_rating == rating
        }
        tag_ok && rating_ok
      }
    }
  })
}

fn available_tags(m: Model) -> List(series.Tag) {
  list.fold(m.results, [], fn(acc, r) {
    case dict.get(m.metadata, r.series_id) {
      Error(_) -> acc
      Ok(meta) -> list.append(acc, meta.tags)
    }
  })
  |> list.fold([], fn(acc, t) {
    case list.any(acc, fn(a: series.Tag) { a.id == t.id }) {
      True -> acc
      False -> list.append(acc, [t])
    }
  })
  |> list.sort(fn(a, b) { string.compare(a.title, b.title) })
}

const all_age_ratings = [
  // series.NotApplicable,
  // series.UnknownRating,
  series.RatingPending,
  series.EarlyChildhood,
  series.Everyone,
  series.Everyone10Plus,
  series.Teen,
  series.Mature17Plus,
  series.AdultsOnly,
]


fn age_rating_label(rating: series.AgeRating) -> String {
  case rating {
    series.NotApplicable -> "Not Applicable"
    series.UnknownRating -> "Unknown"
    series.RatingPending -> "Rating Pending"
    series.EarlyChildhood -> "Early Childhood"
    series.Everyone -> "Everyone"
    series.Everyone10Plus -> "Everyone 10+"
    series.Teen -> "Teen"
    series.Mature17Plus -> "Mature 17+"
    series.AdultsOnly -> "Adults Only"
  }
}

fn spinner() {
  html.div(
    [attribute.class("flex justify-center items-center py-16")],
    [html.i([attribute.class("ph ph-circle-notch animate-spin text-4xl text-zinc-400")], [])],
  )
}

fn empty_state(query: String) {
  html.div(
    [attribute.class("flex flex-col items-center justify-center py-16 gap-3 text-zinc-500")],
    [
      html.i([attribute.class("ph ph-magnifying-glass text-5xl")], []),
      case string.is_empty(query) {
        True ->
          html.p([attribute.class("text-sm")], [element.text("Search for a series")])
        False ->
          html.p([attribute.class("text-sm")], [
            element.text("No results for \"" <> query <> "\""),
          ])
      },
    ],
  )
}

fn filters_panel(
  m: Model,
  avail_tags: List(series.Tag),
) {
  html.div(
    [attribute.class("md:w-48 shrink-0 space-y-6")],
    [
      html.div(
        [attribute.class("space-y-2")],
        [
          html.p(
            [
              attribute.class(
                "text-xs font-semibold text-zinc-400 uppercase tracking-wider",
              ),
            ],
            [element.text("Age Rating")],
          ),
          html.div(
            [attribute.class("flex flex-col gap-1")],
            [
              html.button(
                [
                  attribute.class(case m.active_age_rating {
                    option.None -> "text-sm text-left text-violet-400 font-medium"
                    _ -> "text-sm text-left text-zinc-400 hover:text-zinc-200"
                  }),
                  event.on_click(SetAgeRating(option.None)),
                ],
                [element.text("All")],
              ),
              ..list.map(all_age_ratings, fn(rating) {
                html.button(
                  [
                    attribute.class(case
                      m.active_age_rating == option.Some(rating)
                    {
                      True -> "text-sm text-left text-violet-400 font-medium"
                      False ->
                        "text-sm text-left text-zinc-400 hover:text-zinc-200"
                    }),
                    event.on_click(SetAgeRating(option.Some(rating))),
                  ],
                  [element.text(age_rating_label(rating))],
                )
              })
            ],
          ),
        ],
      ),
      case avail_tags {
        [] ->
          case m.pending_metadata > 0 {
            False -> element.none()
            True ->
              html.div(
                [attribute.class("space-y-2 animate-pulse")],
                [
                  html.div([attribute.class("h-3 w-12 rounded bg-zinc-700")], []),
                  html.div([attribute.class("space-y-1")], [
                    html.div([attribute.class("h-3 w-16 rounded bg-zinc-800")], []),
                    html.div([attribute.class("h-3 w-24 rounded bg-zinc-800")], []),
                    html.div([attribute.class("h-3 w-14 rounded bg-zinc-800")], []),
                  ]),
                ],
              )
          }
        tags ->
          html.div(
            [attribute.class("space-y-2")],
            [
              html.p(
                [
                  attribute.class(
                    "text-xs font-semibold text-zinc-400 uppercase tracking-wider",
                  ),
                ],
                [element.text("Tags")],
              ),
              html.div(
                [attribute.class("max-h-64 overflow-y-auto flex flex-col gap-1")],
                list.map(tags, fn(t) {
                  let active = list.contains(m.active_tags, t.id)
                  html.button(
                    [
                      attribute.class(case active {
                        True ->
                          "text-xs text-left px-2 py-0.5 rounded bg-violet-500 text-white w-fit"
                        False ->
                          "text-xs text-left px-2 py-0.5 rounded bg-zinc-700 text-zinc-300 hover:bg-zinc-600 w-fit"
                      }),
                      event.on_click(ToggleTag(t.id)),
                    ],
                    [element.text(t.title)],
                  )
                }),
              ),
            ],
          )
      },
    ],
  )
}

fn view(m: Model) {
  let results = filtered_results(m)
  let avail_tags = available_tags(m)

  html.div(
    [attribute.class("space-y-4")],
    [
      html.h1(
        [attribute.class("text-xl font-bold text-zinc-200")],
        [
          case string.is_empty(m.query) {
            True -> element.text("Search")
            False -> element.text("Results for \"" <> m.query <> "\"")
          },
        ],
      ),
      case m.loading {
        True -> spinner()
        False ->
          html.div(
            [attribute.class("flex flex-col md:flex-row gap-6")],
            [
              filters_panel(m, avail_tags),
              case results {
                [] -> empty_state(m.query)
                _ ->
                  html.div(
                    [attribute.class("flex-1 flex flex-wrap gap-4")],
                    list.map(results, fn(r) {
                      series_el.card(series.SeriesMinimal(
                        id: r.series_id,
                        name: r.name,
                        localized_name: r.localized_name,
                        created: date.new(""),
                      ))
                    }),
                  )
              },
            ],
          )
      },
    ],
  )
}
