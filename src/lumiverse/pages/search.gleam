import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import lumiverse/api/account
import lumiverse/api/image_url
import lumiverse/api/search
import lumiverse/api/series
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import plinth/browser/document
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
    show_filters: Bool,
  )
}

type Msg {
  QueryChanged(String)
  SearchInputChanged(String)
  SearchSubmit
  GotResults(Result(List(search.SeriesSearchResult), rsvp.Error))
  GotMetadata(Int, Result(series.Metadata, rsvp.Error))
  ToggleTag(Int)
  SetAgeRating(option.Option(series.AgeRating))
  ToggleFilters
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
    [attribute.class("flex w-full flex-col flex-1 p-4"), ..attrs],
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
      show_filters: False,
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
            ..m,
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
            ..m,
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

    SearchInputChanged(q) -> #(Model(..m, query: q), case string.length(q) > 1 {
      True -> search.search(q, GotResults)
      False -> effect.none()
    })

    SearchSubmit ->
      case string.is_empty(m.query) {
        True -> #(m, effect.none())
        False -> #(
          m,
          modem.push(
            "/search?q=" <> uri.percent_encode(m.query),
            option.None,
            option.None,
          ),
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

    SetAgeRating(rating) -> #(Model(..m, active_age_rating: rating), effect.none())

    ToggleFilters -> #(Model(..m, show_filters: !m.show_filters), effect.none())
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

fn age_rating_color(rating: series.AgeRating) -> String {
  case rating {
    series.RatingPending
    | series.EarlyChildhood
    | series.Everyone
    | series.Everyone10Plus -> "bg-emerald-500/20 text-emerald-400"
    series.Teen -> "bg-amber-500/20 text-amber-400"
    series.Mature17Plus -> "bg-orange-500/20 text-orange-400"
    series.AdultsOnly -> "bg-red-500/20 text-red-400"
    _ -> "bg-zinc-700 text-zinc-400"
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
    [attribute.class("flex flex-col items-center justify-center flex-1 gap-3 text-zinc-500")],
    [
      html.i([attribute.class("ph ph-magnifying-glass text-5xl")], []),
      case string.is_empty(query) {
        True ->
          html.p([attribute.class("text-sm")], [element.text("Type something to search")])
        False ->
          html.p([attribute.class("text-sm")], [
            element.text("No results for \"" <> query <> "\""),
          ])
      },
    ],
  )
}

fn search_bar(m: Model) {
  html.div([attribute.class("relative")], [
    html.i(
      [
        attribute.class(
          "ph ph-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400 pointer-events-none",
        ),
      ],
      [],
    ),
    html.input([
      attribute.class(
        "w-full bg-zinc-900 rounded-xl pl-9 pr-4 py-3 text-sm text-zinc-200 outline-none border border-zinc-800 focus:border-violet-500 transition-colors",
      ),
      attribute.attribute("placeholder", "Search series..."),
      attribute.value(m.query),
      event.on_input(SearchInputChanged),
      event.on("keydown", {
        use key <- decode.subfield(["key"], decode.string)
        case key {
          "Enter" -> decode.success(SearchSubmit)
          _ -> decode.failure(SearchSubmit, "not enter")
        }
      }),
    ]),
  ])
}

fn filters_panel(m: Model, avail_tags: List(series.Tag)) {
  html.div(
    [attribute.class("space-y-5")],
    [
      html.div([attribute.class("space-y-2")], [
        html.p(
          [attribute.class("text-xs font-semibold text-zinc-400 uppercase tracking-wider")],
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
                  attribute.class(case m.active_age_rating == option.Some(rating) {
                    True -> "text-sm text-left text-violet-400 font-medium"
                    False -> "text-sm text-left text-zinc-400 hover:text-zinc-200"
                  }),
                  event.on_click(SetAgeRating(option.Some(rating))),
                ],
                [element.text(age_rating_label(rating))],
              )
            })
          ],
        ),
      ]),
      case avail_tags {
        [] ->
          case m.pending_metadata > 0 {
            False -> element.none()
            True ->
              html.div([attribute.class("space-y-2 animate-pulse")], [
                html.div([attribute.class("h-3 w-12 rounded bg-zinc-700")], []),
                html.div([attribute.class("space-y-1")], [
                  html.div([attribute.class("h-3 w-16 rounded bg-zinc-800")], []),
                  html.div([attribute.class("h-3 w-24 rounded bg-zinc-800")], []),
                  html.div([attribute.class("h-3 w-14 rounded bg-zinc-800")], []),
                ]),
              ])
          }
        tags ->
          html.div([attribute.class("space-y-2")], [
            html.p(
              [attribute.class("text-xs font-semibold text-zinc-400 uppercase tracking-wider")],
              [element.text("Tags")],
            ),
            html.div(
              [attribute.class("max-h-48 overflow-y-auto flex flex-wrap gap-1")],
              list.map(tags, fn(t) {
                let active = list.contains(m.active_tags, t.id)
                html.button(
                  [
                    attribute.class(case active {
                      True -> "text-xs px-2 py-0.5 rounded-full bg-violet-500 text-white"
                      False -> "text-xs px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-300 hover:bg-zinc-700"
                    }),
                    event.on_click(ToggleTag(t.id)),
                  ],
                  [element.text(t.title)],
                )
              }),
            ),
          ])
      },
    ],
  )
}

fn result_row(m: Model, r: search.SeriesSearchResult) {
  let user = account.get()
  let cover_url = image_url.series_cover(r.series_id, account.image_key(user))
  html.a(
    [
      attribute.href("/series/" <> int.to_string(r.series_id)),
      attribute.class(
        "flex gap-3 p-3 rounded-lg bg-zinc-900 hover:bg-zinc-800 transition-colors",
      ),
    ],
    [
      html.img([
        attribute.src(cover_url),
        attribute.class("w-12 h-[4.5rem] object-cover rounded flex-shrink-0"),
        attribute.attribute("loading", "lazy"),
      ]),
      html.div([attribute.class("flex flex-col gap-1 min-w-0 flex-1")], [
        html.span(
          [attribute.class("font-semibold text-sm text-zinc-100 leading-snug")],
          [element.text(r.name)],
        ),
        case r.localized_name == "" {
          True -> element.none()
          False ->
            html.span(
              [attribute.class("text-xs text-zinc-400 truncate")],
              [element.text(r.localized_name)],
            )
        },
        case dict.get(m.metadata, r.series_id) {
          Error(_) ->
            html.div(
              [attribute.class("flex gap-1 mt-1 animate-pulse")],
              list.repeat(
                html.div([attribute.class("h-4 w-12 rounded-full bg-zinc-800")], []),
                3,
              ),
            )
          Ok(meta) ->
            html.div([attribute.class("flex flex-wrap gap-1 mt-1")], [
              tag.list(list.take(list.append(meta.tags, meta.genres), 5)),
            ])
        },
      ]),
      case dict.get(m.metadata, r.series_id) {
        Error(_) -> element.none()
        Ok(meta) ->
          case meta.age_rating {
            series.NotApplicable | series.UnknownRating -> element.none()
            rating ->
              html.span(
                [
                  attribute.class(
                    "shrink-0 self-start text-xs font-bold px-1.5 py-0.5 rounded "
                    <> age_rating_color(rating),
                  ),
                ],
                [element.text(age_rating_label(rating))],
              )
          }
      },
    ],
  )
}

fn view(m: Model) {
  let results = filtered_results(m)
  let avail_tags = available_tags(m)
  let has_filters =
    m.active_age_rating != option.None || !list.is_empty(m.active_tags)

  html.div(
    [attribute.class("flex flex-col flex-1 gap-4")],
    [
      search_bar(m),
      case m.loading {
        True -> spinner()
        False ->
          html.div([attribute.class("flex flex-col md:flex-row flex-1 gap-6")], [
            // Filters — collapsible on mobile, sidebar on desktop
            html.div([attribute.class("md:w-48 shrink-0 space-y-3")], [
              html.button(
                [
                  attribute.class(
                    "md:hidden flex items-center gap-2 text-sm font-medium transition-colors "
                    <> case has_filters {
                      True -> "text-violet-400"
                      False -> "text-zinc-400 hover:text-zinc-200"
                    },
                  ),
                  event.on_click(ToggleFilters),
                ],
                [
                  html.i([attribute.class("ph ph-funnel")], []),
                  element.text(case has_filters {
                    True -> "Filters (active)"
                    False -> "Filters"
                  }),
                  html.i(
                    [
                      attribute.class(case m.show_filters {
                        True -> "ph ph-caret-up text-xs"
                        False -> "ph ph-caret-down text-xs"
                      }),
                    ],
                    [],
                  ),
                ],
              ),
              html.div(
                [
                  attribute.class(case m.show_filters {
                    True -> "md:block"
                    False -> "hidden md:block"
                  }),
                ],
                [filters_panel(m, avail_tags)],
              ),
            ]),
            // Results
            case results {
              [] -> empty_state(m.query)
              _ ->
                html.div(
                  [attribute.class("flex-1 flex flex-col gap-2")],
                  list.map(results, result_row(m, _)),
                )
            },
          ])
      },
    ],
  )
}
