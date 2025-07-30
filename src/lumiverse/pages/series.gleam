import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import lumiverse/models/auth
import plinth/javascript/date

import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import lustre/event

import lumiverse/elements/tag
import lumiverse/layout
import lumiverse/model
import lumiverse/models/series
import lumiverse/pages/not_found
import router
import tag_criteria

import lumiverse/components/button.{button}

pub fn page(model: model.Model) -> element.Element(layout.Msg) {
  case model.viewing_series {
    option.Some(serie) ->
      case serie {
        Error(_) -> not_found.page()
        _ -> real_page(model)
      }
    option.None -> real_page(model)
  }
}

fn placeholder_page() {
  html.div(
    [
      class(
        "font-['Poppins'] max-w-screen-xl items-center justify-between mx-auto mb-8 p-4 space-y-4",
      ),
    ],
    [
      html.div([class("flex flex-col sm:flex-row md:flex-row gap-4")], [
        html.div(
          [
            class(
              "max-sm:self-center bg-zinc-800 rounded animate-pulse w-52 h-80",
            ),
          ],
          [],
        ),
        html.div([attribute.class("flex flex-col gap-5")], [
          html.div([attribute.class("space-y-2")], [
            // title (localized)
            html.div(
              [
                attribute.class(
                  "mt-2 mb-3 bg-zinc-800 animate-pulse h-10 w-120",
                ),
              ],
              [],
            ),
            // title (original)
            html.div(
              [attribute.class("bg-zinc-800 animate-pulse h-6 w-48")],
              [],
            ),
          ]),
          html.div([attribute.class("flex flex-wrap gap-2")], [
            button(
              [
                button.solid(button.Primary),
                button.lg(),
                class("w-47.5 h-12"),
                attribute.disabled(True),
              ],
              [
                html.span(
                  [
                    attribute.class(
                      "text-neutral-200 icon-circle-o-notch animate-spin",
                    ),
                  ],
                  [],
                ),
              ],
            ),
          ]),
          html.div([attribute.class("bg-zinc-800 animate-pulse w-80 h-4")], []),
        ]),
      ]),
      html.div([attribute.class("h-52 flex items-center justify-center")], [
        html.span(
          [attribute.class("text-neutral-200 icon-circle-o-notch animate-spin")],
          [],
        ),
      ]),
    ],
  )
}

fn real_page(model: model.Model) -> element.Element(layout.Msg) {
  let assert option.Some(user) = model.user
  let res = {
    use viewing_series <- result.try(option.to_result(
      model.viewing_series,
      placeholder_page(),
    ))
    let assert Ok(srs) = viewing_series
    use metadata <- result.try(result.replace_error(
      dict.get(model.metadatas, srs.id),
      placeholder_page(),
    ))
    use details <- result.try(result.replace_error(
      dict.get(model.series_details, srs.id),
      placeholder_page(),
    ))

    let cover_url =
      router.direct(
        "/api/image/series-cover?seriesId="
        <> int.to_string(srs.id)
        <> "&apiKey="
        <> user.api_key,
      )
    let new_time_range = date.get_time(date.now()) - 3 * { 24 * 60 * 60 * 1000 }

    Ok(
      html.div(
        [
          class(
            "font-['Poppins'] max-w-screen-xl items-center justify-between mx-auto mb-8 p-4 space-y-4",
          ),
        ],
        [
          html.div([class("flex flex-col sm:flex-row md:flex-row gap-4")], [
            html.img([
              class(
                "max-sm:self-center bg-zinc-800 rounded object-cover w-52 h-80",
              ),
              attribute.src(cover_url),
              attribute.rel("preload"),
              attribute.attribute("fetchpriority", "high"),
              attribute.attribute("as", "image"),
              attribute.alt("Cover image for " <> srs.localized_name),
            ]),
            html.div([attribute.class("flex flex-col gap-5")], [
              html.div([attribute.class("space-y-2")], [
                html.span(
                  [
                    attribute.class(
                      "flex flex-nowrap gap-2 font-['Poppins'] font-extrabold",
                    ),
                  ],
                  [
                    case srs.created |> date.get_time() > new_time_range {
                      True -> tag.single_custom("New!", "bg-rose-600")
                      False -> element.none()
                    },
                    html.h1([class("text-xl sm:text-5xl")], [
                      element.text(srs.localized_name),
                    ]),
                  ],
                ),
                html.h2(
                  [class("font-medium sm:font-semibold text-lg sm:text-xl")],
                  [element.text(srs.name)],
                ),
              ]),
              html.div([attribute.class("flex flex-wrap gap-2")], [
                button(
                  [
                    event.on_click(layout.Read(option.None)),
                    button.solid(button.Primary),
                    button.lg(),
                    class("text-white font-semibold"),
                  ],
                  [
                    html.span([attribute.class("icon-book")], []),
                    element.text(case srs.pages_read {
                      0 -> "Start Reading"
                      _ ->
                        case srs.pages_read == srs.pages - 1 {
                          False -> "Continue Reading"
                          True -> "Re-read"
                        }
                    }),
                  ],
                ),
                case metadata.publication_status != series.Completed {
                  False -> element.none()
                  True ->
                    button(
                      [
                        event.on_click(layout.RequestSeriesUpdate(srs)),
                        button.solid(button.Neutral),
                        button.lg(),
                        class("text-white font-semibold"),
                      ],
                      [
                        html.span([attribute.class("icon-history")], []),
                        element.text("Request Update"),
                      ],
                    )
                },
              ]),
              html.div(
                [
                  class(
                    "items-baseline flex flex-wrap gap-2 uppercase font-['Poppins'] font-semibold text-[0.7rem]",
                  ),
                ],
                list.append(
                  {
                    let tags = list.append(metadata.tags, metadata.genres)
                    let assert option.Some(user) = model.user
                    case
                      list.length(tags),
                      option.unwrap(user.roles, []) |> list.contains(auth.Admin)
                    {
                      0, False -> []
                      _, _ -> [
                        tag.list(
                          user,
                          list.sort(tags, tag_criteria.compare),
                          True,
                        ),
                      ]
                    }
                  },
                  [
                    html.div([attribute.class("space-x-1")], [
                      html.span(
                        [
                          class(
                            "align-middle icon-circle "
                            <> case metadata.publication_status {
                              series.Ongoing -> "text-green-400"
                              series.Hiatus -> "text-orange-400"
                              series.Completed | series.Ended -> "text-sky-400"
                              series.Cancelled -> "text-red-400"
                            },
                          ),
                          attribute.attribute(
                            "data-publication",
                            series.publication_title(
                              metadata.publication_status,
                            ),
                          ),
                        ],
                        [],
                      ),
                      html.span([], [
                        element.text(series.publication_title(
                          metadata.publication_status,
                        )),
                      ]),
                    ]),
                  ],
                ),
              ),
            ]),
          ]),
          html.div([attribute.class("space-y-4")], [
            html.p([], [element.text(metadata.summary)]),
            html.div([attribute.class("flex flex-col gap-4")], [
              case list.is_empty(details.volumes) {
                True -> element.none()
                False ->
                  html.div([attribute.class("space-y-4")], [
                    html.h2([attribute.class("font-bold text-3xl")], [
                      element.text("Volumes"),
                    ]),
                    html.div(
                      [attribute.class("flex flex-col gap-2 w-full")],
                      list.map(details.volumes, fn(vol: series.Volume) {
                        button(
                          [
                            event.on_click(layout.Read(option.Some(vol.id))),
                            button.solid(button.Neutral),
                            button.lg(),
                            class("text-white font-semibold"),
                          ],
                          [
                            html.span([attribute.class("icon-book")], []),
                            element.text(vol.name),
                          ],
                        )
                      }),
                    ),
                  ])
              },
              {
                let chapters_from_vols =
                  list.map(details.volumes, fn(vol: series.Volume) {
                    list.map(vol.chapters, fn(chp: series.Chapter) {
                      #(chp.id, True)
                    })
                  })
                  |> list.flatten
                  |> dict.from_list
                let filtered_chapters =
                  list.filter(
                    list.append(details.chapters, details.specials),
                    fn(chp: series.Chapter) {
                      bool.negate(dict.has_key(chapters_from_vols, chp.id))
                    },
                  )
                case list.is_empty(filtered_chapters) {
                  True -> element.none()
                  False ->
                    html.div([attribute.class("space-y-4")], [
                      html.h2([attribute.class("font-bold text-3xl")], [
                        element.text("Chapters"),
                      ]),
                      html.div(
                        [attribute.class("flex flex-col gap-2 w-ful")],
                        list.map(
                          list.sort(filtered_chapters, fn(chp_b, chp_a) {
                            float.compare(chp_a.sort_order, chp_b.sort_order)
                          }),
                          fn(chp: series.Chapter) {
                            html.div([attribute.class("w-full group")], [
                              button(
                                [
                                  event.on_click(
                                    layout.Read(option.Some(chp.id)),
                                  ),
                                  button.solid(button.Neutral),
                                  button.lg(),
                                  class(
                                    "group-hover:bg-zinc-700/60 w-full rounded-b-none text-white font-semibold",
                                  ),
                                ],
                                [
                                  html.span([attribute.class("icon-book")], []),
                                  element.text(chp.title),
                                ],
                              ),
                              html.div(
                                [
                                  case chp.pages_read {
                                    0 ->
                                      attribute.class(
                                        "group-hover:bg-zinc-700/60 bg-zinc-700",
                                      )
                                    _ -> attribute.class("bg-zinc-800")
                                  },
                                  attribute.class("w-full rounded-b-md h-1"),
                                ],
                                [
                                  html.div(
                                    [
                                      case chp.pages_read == chp.pages - 1 {
                                        False ->
                                          attribute.class("rounded-bl-md")
                                        True -> attribute.class("rounded-b-lg")
                                      },
                                      attribute.class("bg-violet-500 h-1"),
                                      attribute.style(
                                        "width",
                                        int.to_string(
                                          chp.pages
                                          / int.subtract(chp.pages_read, 1)
                                          * 100,
                                        )
                                          <> "%",
                                      ),
                                    ],
                                    [],
                                  ),
                                ],
                              ),
                            ])
                          },
                        ),
                      ),
                    ])
                }
              },
            ]),
          ]),
        ],
      ),
    )
  }

  result.unwrap_both(res)
}
