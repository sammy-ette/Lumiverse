import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result

import lustre/attribute
import lustre/element
import lustre/element/html
import plinth/javascript/date

import lumiverse/elements/series
import lumiverse/elements/tag
import lumiverse/layout
import lumiverse/model
import lumiverse/models/series as series_model
import router
import tag_criteria

fn placeholder_carousel_item() {
  html.div(
    [
      attribute.class(
        "flex-shrink-0 w-full gap-6 relative flex flex-nowrap p-4 pt-16 space-y-2",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex-shrink-0 max-w-screen-xl mx-auto w-full gap-6 relative flex flex-nowrap space-y-2",
          ),
        ],
        [
          html.div(
            [
              attribute.class(
                "max-sm:self-center bg-zinc-800 rounded animate-pulse w-58 h-80",
              ),
            ],
            [],
          ),
        ],
      ),
    ],
  )
}

pub fn page(model: model.Model) -> element.Element(layout.Msg) {
  let assert option.Some(user) = model.user
  html.div([], [
    html.div([attribute.class("w-full bg-zinc-900 mb-4")], [
      html.div([attribute.class("overflow-hidden")], [
        html.div([attribute.class("max-w-screen-xl mx-auto")], [
          html.h1(
            [
              attribute.class(
                "z-30 absolute mx-auto py-4 pt-2 text-lg sm:text-3xl font-bold sm:font-extrabold font-['Poppins']",
              ),
            ],
            [element.text("Popular on Lumiverse")],
          ),
        ]),
        html.div(
          [
            attribute.style(
              "transform",
              "translateX(-"
                <> int.to_string(model.home.carousel_index * 100)
                <> "%)",
            ),
            attribute.class(
              "mx-auto relative flex transition-transform duration-500 ease-in-out w-full",
            ),
          ],
          case model.home.carousel |> list.is_empty {
            True -> [placeholder_carousel_item()]
            False ->
              list.index_map(
                model.home.carousel,
                fn(srs: series_model.Info, idx: Int) {
                  let res = {
                    use metadata <- result.try(result.replace_error(
                      model.metadatas |> dict.get(srs.id),
                      placeholder_carousel_item(),
                    ))
                    let cover_url =
                      router.direct(
                        "/api/image/series-cover?seriesId="
                        <> int.to_string(srs.id)
                        <> "&apiKey="
                        <> user.api_key,
                      )
                    let new_time_range =
                      date.get_time(date.now()) - 3 * { 24 * 60 * 60 * 1000 }

                    Ok(
                      html.div(
                        [
                          attribute.class(
                            "flex-shrink-0 w-full gap-6 relative flex flex-nowrap p-4 pt-16 space-y-2",
                          ),
                        ],
                        [
                          html.img([
                            attribute.class(
                              "absolute left-0 top-0 object-cover w-full",
                            ),
                            attribute.src(cover_url),
                            attribute.rel("preload"),
                            attribute.attribute("fetchpriority", "high"),
                            attribute.attribute("as", "image"),
                          ]),
                          html.div(
                            [
                              attribute.class(
                                "absolute left-0 top-0 w-full h-full bg-linear-to-t from-zinc-950 to-zinc-950/50 backdrop-blur-sm z-20",
                              ),
                            ],
                            [],
                          ),
                          html.div(
                            [
                              attribute.class(
                                "flex-shrink-0 max-w-screen-xl mx-auto w-full gap-6 relative flex flex-nowrap space-y-2",
                              ),
                            ],
                            [
                              html.img([
                                attribute.class(
                                  "bg-zinc-800 rounded w-72 h-80 z-20",
                                ),
                                attribute.src(cover_url),
                                attribute.rel("preload"),
                                attribute.attribute("fetchpriority", "high"),
                                attribute.attribute("as", "image"),
                                attribute.alt(
                                  "Cover image for " <> srs.localized_name,
                                ),
                              ]),
                              html.div(
                                [
                                  attribute.class(
                                    "flex flex-col z-20 justify-between w-full",
                                  ),
                                ],
                                [
                                  html.div(
                                    [attribute.class("flex flex-col gap-4")],
                                    [
                                      html.div([attribute.class("space-y-1")], [
                                        html.div(
                                          [
                                            attribute.class(
                                              "flex flex-nowrap gap-2 font-['Poppins'] font-extrabold",
                                            ),
                                          ],
                                          [
                                            case
                                              srs.created |> date.get_time()
                                              > new_time_range
                                            {
                                              True ->
                                                tag.single_custom(
                                                  "New!",
                                                  "bg-rose-600",
                                                )
                                              False -> element.none()
                                            },
                                            html.h2(
                                              [
                                                attribute.class(
                                                  "text-lg sm:text-3xl ",
                                                ),
                                              ],
                                              [element.text(srs.localized_name)],
                                            ),
                                          ],
                                        ),
                                        html.h3(
                                          [
                                            attribute.class(
                                              "font-medium sm:font-semibold text-sm sm:text-md",
                                            ),
                                          ],
                                          [element.text(srs.name)],
                                        ),
                                      ]),
                                      html.div(
                                        [
                                          attribute.class(
                                            "items-baseline flex flex-wrap gap-2 uppercase font-['Poppins'] font-semibold text-[0.7rem]",
                                          ),
                                        ],
                                        {
                                          let tags =
                                            list.append(
                                              metadata.tags,
                                              metadata.genres,
                                            )
                                          let assert option.Some(user) =
                                            model.user
                                          case list.length(tags) {
                                            0 -> []
                                            _ -> [
                                              tag.list(
                                                user,
                                                list.sort(
                                                  tags,
                                                  tag_criteria.compare,
                                                ),
                                                False,
                                              ),
                                            ]
                                          }
                                        },
                                      ),
                                      html.p([], [
                                        element.text(metadata.summary),
                                      ]),
                                    ],
                                  ),
                                  html.div(
                                    [
                                      attribute.class(
                                        "font-['Poppins'] flex justify-between",
                                      ),
                                    ],
                                    [
                                      html.span(
                                        [
                                          case idx {
                                            0 ->
                                              attribute.class("text-violet-400")
                                            _ -> attribute.none()
                                          },
                                          attribute.class("font-semibold"),
                                        ],
                                        [
                                          element.text(
                                            "#"
                                            <> int.to_string(idx + 1)
                                            <> " Popular Series",
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  }

                  result.unwrap_both(res)
                },
              )
          },
        ),
      ]),
    ]),
    html.div(
      [
        attribute.class(
          "max-w-screen-xl flex flex-nowrap flex-col mx-auto mb-8 px-4 space-y-5",
        ),
      ],
      list.take(
        list.flatten([
          list.map(model.home.series_lists, fn(serie_list) {
            series.series_list(
              list.map(serie_list.items, fn(serie) { series.card(model, serie) }),
              serie_list.title,
            )
          }),
          list.repeat(
            series.placeholder_series_list(),
            model.home.dashboard_count,
          ),
        ]),
        model.home.dashboard_count,
      ),
    ),
  ])
}
