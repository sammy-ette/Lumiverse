import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lumiverse/api/filter
import lumiverse/api/series as series_api
import lumiverse/components
import lumiverse/elements/button
import lumiverse/elements/dropdown
import lumiverse/elements/series
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import plinth/browser/document
import rsvp

type TagState {
  TagInactive
  TagIncluded
  TagExcluded
}

type Model {
  Model(
    series: option.Option(Result(List(series_api.SeriesMinimal), rsvp.Error)),
    available_genres: List(series_api.Tag),
    available_tags: List(series_api.Tag),
    sort_field: filter.SortField,
    ascending: Bool,
    active_statuses: List(series_api.Publication),
    active_ratings: List(series_api.AgeRating),
    included_genres: List(series_api.Tag),
    excluded_genres: List(series_api.Tag),
    included_tags: List(series_api.Tag),
    excluded_tags: List(series_api.Tag),
    show_sort_panel: Bool,
    tag_search: String,
    page: Int,
    has_more: Bool,
    sidebar_open: Bool,
  )
}

type Msg {
  SeriesLoaded(Result(List(series_api.SeriesMinimal), rsvp.Error))
  GenresLoaded(Result(List(series_api.Tag), rsvp.Error))
  TagsLoaded(Result(List(series_api.Tag), rsvp.Error))
  SetSort(filter.SortField)
  ToggleAscending
  ToggleStatus(series_api.Publication)
  ToggleAgeRating(series_api.AgeRating)
  ToggleGenre(series_api.Tag)
  ToggleTag(series_api.Tag)
  ToggleSortPanel
  TagSearchChanged(String)
  GoToPage(Int)
  ToggleSidebar
  ResetFilters
  Nothing
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "all-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "all-page",
    [
      attribute.class("flex w-full flex-col flex-1 min-h-0 overflow-hidden"),
      ..attrs
    ],
    [],
  )
}

fn init(_) {
  let m =
    Model(
      series: option.None,
      available_genres: [],
      available_tags: [],
      sort_field: filter.SortName,
      ascending: True,
      active_statuses: [],
      active_ratings: [],
      included_genres: [],
      excluded_genres: [],
      included_tags: [],
      excluded_tags: [],
      show_sort_panel: False,
      tag_search: "",
      page: 1,
      has_more: False,
      sidebar_open: False,
    )
  #(
    m,
    effect.batch([
      do_fetch(m),
      series_api.genres(GenresLoaded),
      series_api.tags(TagsLoaded),
    ]),
  )
}

fn do_fetch(m: Model) {
  let status_stmts =
    list.map(m.active_statuses, fn(s) {
      filter.Statement(
        filter.Equal,
        filter.PublicationStatus,
        series_api.publication_to_string(s),
      )
    })
  let rating_stmts =
    list.map(m.active_ratings, fn(r) {
      filter.Statement(
        filter.Equal,
        filter.AgeRating,
        series_api.age_rating_to_int(r) |> int.to_string,
      )
    })
  let genre_stmts =
    list.append(
      list.map(m.included_genres, fn(t) {
        filter.Statement(filter.Contains, filter.Genres, int.to_string(t.id))
      }),
      list.map(m.excluded_genres, fn(t) {
        filter.Statement(
          filter.DoesNotContain,
          filter.Genres,
          int.to_string(t.id),
        )
      }),
    )
  let tag_stmts =
    list.append(
      list.map(m.included_tags, fn(t) {
        filter.Statement(filter.Contains, filter.Tags, int.to_string(t.id))
      }),
      list.map(m.excluded_tags, fn(t) {
        filter.Statement(
          filter.DoesNotContain,
          filter.Tags,
          int.to_string(t.id),
        )
      }),
    )
  let stmts =
    list.append(
      list.append(list.append(status_stmts, rating_stmts), genre_stmts),
      tag_stmts,
    )
  series_api.all(
    m.sort_field,
    m.ascending,
    stmts,
    filter.And,
    m.page,
    31,
    SeriesLoaded,
  )
}

fn refetch(m: Model) {
  #(Model(..m, series: option.None), do_fetch(m))
}

fn refetch_from_page_1(m: Model) {
  refetch(Model(..m, page: 1))
}

fn update(m: Model, msg: Msg) {
  case msg {
    SeriesLoaded(Ok(items)) -> {
      let has_more = list.length(items) > 30
      let display_items = list.take(items, 30)
      #(
        Model(..m, series: option.Some(Ok(display_items)), has_more:),
        effect.none(),
      )
    }
    SeriesLoaded(Error(e)) -> #(
      Model(..m, series: option.Some(Error(e))),
      effect.none(),
    )

    GenresLoaded(Ok(genres)) -> #(
      Model(..m, available_genres: genres),
      effect.none(),
    )
    GenresLoaded(Error(_)) -> #(m, effect.none())

    TagsLoaded(Ok(tags)) -> #(Model(..m, available_tags: tags), effect.none())
    TagsLoaded(Error(_)) -> #(m, effect.none())

    SetSort(sf) -> refetch_from_page_1(Model(..m, sort_field: sf))

    ToggleAscending ->
      refetch_from_page_1(Model(..m, ascending: m.ascending |> bool.negate))

    ToggleStatus(status) -> {
      let new_statuses = case list.contains(m.active_statuses, status) {
        True -> list.filter(m.active_statuses, fn(s) { s != status })
        False -> [status, ..m.active_statuses]
      }
      refetch_from_page_1(Model(..m, active_statuses: new_statuses))
    }

    ToggleAgeRating(rating) -> {
      let new_ratings = case list.contains(m.active_ratings, rating) {
        True -> list.filter(m.active_ratings, fn(r) { r != rating })
        False -> [rating, ..m.active_ratings]
      }
      refetch_from_page_1(Model(..m, active_ratings: new_ratings))
    }

    ToggleGenre(t) ->
      refetch_from_page_1(
        case
          list.contains(m.included_genres, t),
          list.contains(m.excluded_genres, t)
        {
          True, _ ->
            Model(
              ..m,
              included_genres: list.filter(m.included_genres, fn(g) { g != t }),
              excluded_genres: [t, ..m.excluded_genres],
            )
          _, True ->
            Model(
              ..m,
              excluded_genres: list.filter(m.excluded_genres, fn(g) { g != t }),
            )
          False, False -> Model(..m, included_genres: [t, ..m.included_genres])
        },
      )

    ToggleTag(t) ->
      refetch_from_page_1(
        case
          list.contains(m.included_tags, t),
          list.contains(m.excluded_tags, t)
        {
          True, _ ->
            Model(
              ..m,
              included_tags: list.filter(m.included_tags, fn(x) { x != t }),
              excluded_tags: [t, ..m.excluded_tags],
            )
          _, True ->
            Model(
              ..m,
              excluded_tags: list.filter(m.excluded_tags, fn(x) { x != t }),
            )
          False, False -> Model(..m, included_tags: [t, ..m.included_tags])
        },
      )

    ToggleSortPanel -> #(
      Model(..m, show_sort_panel: !m.show_sort_panel),
      effect.none(),
    )

    TagSearchChanged(q) -> #(Model(..m, tag_search: q), effect.none())

    GoToPage(p) -> refetch(Model(..m, page: p))

    ToggleSidebar -> #(Model(..m, sidebar_open: !m.sidebar_open), effect.none())

    ResetFilters ->
      refetch_from_page_1(
        Model(
          ..m,
          active_statuses: [],
          active_ratings: [],
          included_genres: [],
          excluded_genres: [],
          included_tags: [],
          excluded_tags: [],
        ),
      )

    Nothing -> #(m, effect.none())
  }
}

fn view(m: Model) {
  let _ = document.set_title("All Series | Lumiverse")

  html.div(
    [attribute.class("flex flex-1 min-h-0"), components.redirect_click(Nothing)],
    [
      html.div(
        [
          attribute.class(
            "flex flex-col overflow-hidden transition-[width] duration-300 ease-in-out shrink-0 "
            <> case m.sidebar_open {
              True -> "w-72"
              False -> "w-0"
            },
          ),
        ],
        [filter_panel(m)],
      ),
      html.div(
        [attribute.class("flex flex-col flex-1 min-h-0 overflow-hidden")],
        [
          control_bar(m),
          html.div(
            [attribute.class("flex flex-col flex-1 min-h-0 overflow-y-auto")],
            [
              series_grid(m),
            ],
          ),
        ],
      ),
    ],
  )
}

fn control_bar(m: Model) {
  html.div(
    [
      attribute.class(
        "border-b border-zinc-700 flex justify-between items-center py-4 px-6",
      ),
    ],
    [
      html.div([attribute.class("flex items-center gap-3")], [
        button.icon("ph ph-[funnel]", "Toggle filters", [
          event.on_click(ToggleSidebar),
          button.tertiary(),
          attribute.class("text-zinc-300"),
        ]),
        case m.series {
          option.Some(Ok(srs_list)) ->
            html.span([], [
              html.span(
                [
                  attribute.class(
                    "font-[Poppins,sans-serif] font-extrabold text-xl color-white",
                  ),
                ],
                [
                  element.text(int.to_string(list.length(srs_list))),
                ],
              ),
              html.span([attribute.class("text-sm text-zinc-400")], [
                element.text(" series"),
              ]),
            ])
          _ -> element.none()
        },
      ]),
      html.div([attribute.class("flex items-center gap-3")], [
        dropdown.dropdown(
          m.show_sort_panel,
          ToggleSortPanel,
          button.icon_label(
            "ph ph-[sort-ascending]",
            "Sort: "
              <> case m.sort_field {
              filter.SortName -> "Name"
              filter.LastChapterAdded -> "Last Updated"
              filter.CreatedDate -> "Date Added"
              _ -> "Other"
            },
            [
              button.secondary(),
            ],
          ),
          [
            dropdown.MenuItem(
              "Name",
              option.None,
              SetSort(filter.SortName),
              option.Some("ph ph-[identification-badge]"),
              m.sort_field == filter.SortName,
            ),
            dropdown.MenuItem(
              "Last Updated",
              option.None,
              SetSort(filter.LastChapterAdded),
              option.Some("ph ph-[fire-simple]"),
              m.sort_field == filter.LastChapterAdded,
            ),
            dropdown.MenuItem(
              "Date Added",
              option.None,
              SetSort(filter.CreatedDate),
              option.Some("ph ph-[clock-clockwise]"),
              m.sort_field == filter.CreatedDate,
            ),
          ],
        ),
        button.icon(
          case m.ascending {
            False -> "ph ph-[arrow-up]"
            True -> "ph ph-[arrow-down]"
          },
          "Toggle sort direction",
          [
            button.secondary(),
            event.on_click(ToggleAscending),
            attribute.title("Toggle Ascending/Descending"),
          ],
        ),
      ]),
    ],
  )
}

fn filter_panel(m: Model) {
  html.div(
    [
      attribute.class(
        "flex flex-col gap-4 p-4 w-72 shrink-0 flex-1 border-r border-zinc-700 overflow-hidden min-h-0",
      ),
    ],
    [
      filter_section(
        "Age Rating",
        "",
        [
          series_api.Everyone,
          series_api.Everyone10Plus,
          series_api.Teen,
          series_api.Mature17Plus,
          series_api.AdultsOnly,
        ]
          |> list.map(fn(rating) {
            filter_chip(
              series.age_rating_label(rating),
              case rating {
                series_api.RatingPending
                | series_api.EarlyChildhood
                | series_api.Everyone
                | series_api.Everyone10Plus -> "bg-emerald-500 text-emerald-400"
                series_api.Teen -> "bg-amber-500 text-amber-400"
                series_api.Mature17Plus -> "bg-orange-500 text-orange-400"
                series_api.AdultsOnly -> "bg-red-500 text-red-400"
                _ -> "bg-zinc-700 text-zinc-400"
              },
              ToggleAgeRating(rating),
              list.contains(m.active_ratings, rating),
            )
          }),
      ),
      filter_section(
        "Publication Status",
        "",
        [
          series_api.Completed,
          series_api.Ended,
          series_api.Ongoing,
          series_api.Cancelled,
          series_api.Hiatus,
        ]
          |> list.map(fn(status) {
            filter_chip(
              series_api.publication_label(status),
              case status {
                series_api.Ongoing -> "text-green-400"
                series_api.Hiatus -> "text-orange-400"
                series_api.Completed | series_api.Ended -> "text-sky-400"
                series_api.Cancelled -> "text-red-400"
                _ -> "text-gray-400"
              },
              ToggleStatus(status),
              list.contains(m.active_statuses, status),
            )
          }),
      ),
      {
        let q = string.lowercase(m.tag_search)
        let visible_genres = case m.tag_search {
          "" -> m.available_genres
          _ ->
            list.filter(m.available_genres, fn(t) {
              string.contains(string.lowercase(t.title), q)
            })
        }
        let visible_tags = case m.tag_search {
          "" -> m.available_tags
          _ ->
            list.filter(m.available_tags, fn(t) {
              string.contains(string.lowercase(t.title), q)
            })
        }

        html.div([attribute.class("flex flex-col gap-2 flex-1 min-h-0")], [
          html.div(
            [attribute.class("flex items-baseline justify-between gap-2")],
            [
              html.h2(
                [
                  attribute.class(
                    "font-[Poppins,sans-serif] uppercase text-sm text-zinc-500 font-semibold",
                  ),
                ],
                [element.text("Tags & Genres")],
              ),
              html.span([attribute.class("text-xs text-zinc-400")], [
                element.text("tap: include → exclude"),
              ]),
            ],
          ),
          html.label(
            [
              attribute.class(
                "flex w-full items-center gap-2 bg-zinc-900 rounded-full px-3 py-2 text-zinc-400",
              ),
            ],
            [
              html.i([attribute.class("ph ph-[magnifying-glass] text-sm")], []),
              html.input([
                attribute.class(
                  "bg-transparent outline-none text-sm text-white placeholder:text-zinc-400 w-full",
                ),
                attribute.placeholder("Filter tags..."),
                attribute.value(m.tag_search),
                event.on_input(TagSearchChanged),
              ]),
            ],
          ),
          html.div(
            [
              attribute.class(
                "flex flex-wrap gap-2 overflow-y-auto content-start flex-1 min-h-0",
              ),
            ],
            list.append(
              list.sort(visible_genres, tag.compare)
                |> list.map(fn(t) {
                  let state = case
                    list.contains(m.included_genres, t),
                    list.contains(m.excluded_genres, t)
                  {
                    True, _ -> TagIncluded
                    _, True -> TagExcluded
                    _, _ -> TagInactive
                  }
                  filter_tag(t.title, state, ToggleGenre(t))
                }),
              list.sort(visible_tags, tag.compare)
                |> list.map(fn(t) {
                  let state = case
                    list.contains(m.included_tags, t),
                    list.contains(m.excluded_tags, t)
                  {
                    True, _ -> TagIncluded
                    _, True -> TagExcluded
                    _, _ -> TagInactive
                  }
                  filter_tag(t.title, state, ToggleTag(t))
                }),
            ),
          ),
        ])
      },
    ],
  )
}

fn filter_chip(label: String, color: String, on_click: msg, active: Bool) {
  html.button(
    [
      event.on_click(on_click),
      attribute.class(
        "ring-0 py-1 px-2 transition-all duration-200 ease-in-out border-1 rounded-lg font-medium",
      ),
      case active {
        False ->
          attribute.class(
            "border-zinc-800 hover:border-zinc-600 text-zinc-400 hover:text-zinc-100",
          )
        True -> attribute.class("bg-violet-500/20 border-violet-500 text-white")
      },
    ],
    [
      html.span([attribute.class("inline-flex items-center gap-1.5")], [
        html.i(
          [
            attribute.class(color),
            attribute.class("text-xs ph ph-[circle--fill]"),
          ],
          [],
        ),
        element.text(label),
      ]),
    ],
  )
}

fn filter_tag(label: String, state: TagState, on_click: msg) {
  html.button(
    [
      event.on_click(on_click),
      attribute.class(tag.tag_appearance),
      attribute.class(
        "capitalize rounded-full py-0.5 px-2.5 select-none transition-colors duration-150 inline-flex items-center gap-1 border border-transparent",
      ),
      case state {
        TagInactive -> attribute.class("opacity-50 hover:opacity-80")
        TagIncluded | TagExcluded -> attribute.class("opacity-100")
      },
      case state {
        TagInactive -> tag.color(label)
        TagIncluded -> tag.included_style(label)
        TagExcluded -> tag.excluded_style(label)
      },
      case state {
        TagExcluded -> tag.excluded_border(label)
        _ -> attribute.none()
      },
    ],
    [
      case state {
        TagIncluded ->
          html.i([attribute.class("ph ph-[check--bold] text-[0.6rem]")], [])
        TagExcluded ->
          html.i([attribute.class("ph ph-[minus--bold] text-[0.6rem]")], [])
        TagInactive -> element.none()
      },
      html.span(
        [
          case state {
            TagExcluded -> attribute.class("line-through")
            _ -> attribute.none()
          },
        ],
        [element.text(label)],
      ),
    ],
  )
}

fn filter_section(
  title: String,
  hint: String,
  contents: List(element.Element(a)),
) {
  html.div([attribute.class("flex flex-col gap-2")], [
    html.div([attribute.class("flex items-baseline justify-between gap-2")], [
      html.h2(
        [
          attribute.class(
            "font-[Poppins,sans-serif] uppercase text-sm text-zinc-500 font-semibold",
          ),
        ],
        [element.text(title)],
      ),
      case hint {
        "" -> element.none()
        _ ->
          html.span([attribute.class("text-xs text-zinc-400")], [
            element.text(hint),
          ])
      },
    ]),
    html.div([attribute.class("flex flex-wrap gap-2")], contents),
  ])
}

fn series_grid(m: Model) {
  case m.series {
    option.None ->
      html.div([attribute.class("flex flex-1 items-center justify-center")], [
        html.div(
          [
            attribute.class(
              "w-8 h-8 rounded-full border-2 border-zinc-700 border-t-violet-500 animate-spin",
            ),
          ],
          [],
        ),
      ])
    option.Some(Error(_)) ->
      html.div(
        [
          attribute.class(
            "flex flex-1 items-center justify-center text-zinc-500",
          ),
        ],
        [element.text("Failed to load series")],
      )
    option.Some(Ok([])) ->
      html.div(
        [
          attribute.class(
            "flex flex-col gap-2 flex-1 items-center justify-center text-zinc-500",
          ),
        ],
        [
          element.text("No series matched the filters."),
          button.button("Clear Filters", [
            event.on_click(ResetFilters),
            button.tertiary(),
          ]),
        ],
      )
    option.Some(Ok(items)) ->
      html.div([attribute.class("px-6 py-4 flex flex-col flex-1 gap-4")], [
        html.div(
          [
            attribute.class(
              "flex-1 grid gap-3 items-start content-start grid-cols-[repeat(auto-fill,minmax(8rem,1fr))]",
            ),
          ],
          list.map(items, series.grid_card),
        ),
        pagination_bar(m),
      ])
  }
}

fn pagination_bar(m: Model) {
  let prev_disabled = m.page <= 1
  let next_disabled = m.has_more |> bool.negate
  html.div([attribute.class("flex items-center justify-center gap-3 py-2")], [
    button.icon("ph ph-[arrow-left]", "Previous page", [
      event.on_click(GoToPage(m.page - 1)),
      button.secondary(),
      attribute.disabled(prev_disabled),
    ]),
    html.span([attribute.class("text-sm text-zinc-400")], [
      element.text("Page " <> int.to_string(m.page)),
    ]),
    button.icon("ph ph-[arrow-right]", "Next page", [
      event.on_click(GoToPage(m.page + 1)),
      button.secondary(),
      attribute.disabled(next_disabled),
    ]),
  ])
}
