import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option

import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import lustre/event

import lumiverse/elements/chapter
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

fn real_page(model: model.Model) -> element.Element(layout.Msg) {
  let assert option.Some(user) = model.user
  html.div(
    [
      class(
        "font-['Poppins'] max-w-screen-xl items-center justify-between mx-auto mb-8 p-4 space-y-4",
      ),
    ],
    [
      html.div([class("flex flex-col sm:flex-row md:flex-row gap-4")], [
        case model.viewing_series {
          option.Some(serie) -> {
            let assert Ok(srs) = serie
            let cover_url =
              router.direct(
                "/api/image/series-cover?seriesId="
                <> int.to_string(srs.id)
                <> "&apiKey="
                <> user.api_key,
              )

            html.img([
              class(
                "max-sm:self-center bg-zinc-800 rounded object-cover w-52 h-80",
              ),
              attribute.src(cover_url),
              attribute.rel("preload"),
              attribute.attribute("fetchpriority", "high"),
              attribute.attribute("as", "image"),
              attribute.alt("Cover image for " <> srs.localized_name),
            ])
          }
          option.None ->
            html.div(
              [
                class(
                  "max-sm:self-center bg-zinc-800 rounded animate-pulse w-52 h-80",
                ),
              ],
              [],
            )
        },
        html.div([attribute.class("flex flex-col gap-5")], [
          html.div([class("space-y-2")], case model.viewing_series {
            option.Some(serie) -> {
              let assert Ok(srs) = serie

              [
                html.span(
                  [
                    attribute.class(
                      "flex flex-wrap gap-2 font-['Poppins'] font-extrabold",
                    ),
                  ],
                  [
                    tag.single_custom("New!", "bg-rose-600"),
                    html.h1([class("text-xl sm:text-5xl")], [
                      element.text(srs.localized_name),
                    ]),
                  ],
                ),
                html.h2(
                  [class("font-medium sm:font-semibold text-lg sm:text-xl")],
                  [element.text(srs.name)],
                ),
              ]
            }
            option.None -> [
              html.div([class("bg-zinc-800 animate-pulse h-10 w-96")], []),
              html.div([class("bg-zinc-800 animate-pulse h-7 w-48")], []),
            ]
          }),
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
                element.text("Start Reading"),
              ],
            ),
            case model.viewing_series {
              option.None -> element.none()
              option.Some(serie) -> {
                let assert Ok(srs) = serie
                let assert Ok(metadata) = dict.get(model.metadatas, srs.id)
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
                }
              }
            },
          ]),
          case model.viewing_series {
            option.Some(serie) -> {
              let assert Ok(srs) = serie
              let assert Ok(metadata) = dict.get(model.metadatas, srs.id)

              html.div(
                [
                  class(
                    "items-baseline flex flex-wrap gap-2 uppercase font-['Poppins'] font-semibold text-[0.7rem]",
                  ),
                ],
                list.append(
                  {
                    let tags =
                      list.append(
                        list.map(metadata.tags, fn(t) { t.title }),
                        list.map(metadata.genres, fn(t) { t.title }),
                      )
                    case list.length(tags) {
                      0 -> []
                      _ -> [tag.list(list.sort(tags, tag_criteria.compare))]
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
              )
            }
            option.None ->
              html.div([class("bg-zinc-800 animate-pulse w-80 h-6")], [])
          },
        ]),
      ]),
      case model.viewing_series {
        option.None -> html.div([], [])
        option.Some(serie) -> {
          let assert Ok(srs) = serie
          let assert Ok(metadata) = dict.get(model.metadatas, srs.id)
          let assert Ok(series_details) = dict.get(model.series_details, srs.id)

          html.div([attribute.class("space-y-4")], [
            html.p([], [element.text(metadata.summary)]),
            html.div([attribute.class("flex flex-col gap-4")], [
              case list.is_empty(series_details.volumes) {
                True -> element.none()
                False ->
                  html.div([attribute.class("space-y-4")], [
                    html.h2([attribute.class("font-bold text-3xl")], [
                      element.text("Volumes"),
                    ]),
                    html.div(
                      [attribute.class("flex flex-col gap-2 w-full")],
                      list.map(series_details.volumes, fn(vol: series.Volume) {
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
                  list.map(series_details.volumes, fn(vol: series.Volume) {
                    list.map(vol.chapters, fn(chp: series.Chapter) {
                      #(chp.id, True)
                    })
                  })
                  |> list.flatten
                  |> dict.from_list
                let filtered_chapters =
                  list.filter(series_details.chapters, fn(chp: series.Chapter) {
                    echo dict.has_key(chapters_from_vols, chp.id)
                    bool.negate(dict.has_key(chapters_from_vols, chp.id))
                  })
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
                            button(
                              [
                                event.on_click(layout.Read(option.Some(chp.id))),
                                button.solid(button.Neutral),
                                button.lg(),
                                class("text-white font-semibold"),
                              ],
                              [
                                html.span([attribute.class("icon-book")], []),
                                element.text(chp.title),
                              ],
                            )
                          },
                        ),
                      ),
                    ])
                }
              },
            ]),
          ])
        }
      },
    ],
  )
}
