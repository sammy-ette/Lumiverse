import gleam/int
import gleam/list
import gleam/option
import gleam/result
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/reader
import lumiverse/api/series
import lumiverse/elements/button
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import plinth/javascript/date
import rsvp

type Model {
  Model(series: option.Option(Result(series.Series, rsvp.Error)))
}

type Msg {
  SeriesID(Int)
  SeriesRetrieved(Result(series.Series, rsvp.Error))
  MetadataRetrieved(Result(series.Metadata, rsvp.Error))
  Read
  RequestUpdate
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
}

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("series-id", fn(value) {
        int.parse(value) |> result.map(SeriesID)
      }),
    ])
  lustre.register(app, "series-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "series-page",
    [attribute.class("flex-1 flex flex-col"), ..attrs],
    [],
  )
}

pub fn id(id: String) {
  attribute.attribute("series-id", id)
}

fn init(_) {
  #(Model(series: option.None), effect.none())
}

fn update(m: Model, msg: Msg) {
  case msg {
    SeriesID(id) -> #(m, series.get(id, SeriesRetrieved))
    SeriesRetrieved(Ok(srs)) -> {
      #(
        Model(series: option.Some(Ok(srs))),
        series.metadata(srs.id, MetadataRetrieved),
      )
    }
    SeriesRetrieved(Error(e)) -> #(
      Model(series: option.Some(Error(e))),
      effect.none(),
    )
    MetadataRetrieved(Ok(metadata)) -> {
      let assert option.Some(Ok(srs)) = m.series
      #(
        Model(
          series: option.Some(Ok(
            series.Series(..srs, metadata: option.Some(metadata)),
          )),
        ),
        effect.none(),
      )
    }
    MetadataRetrieved(Error(_)) -> #(m, effect.none())
    Read -> {
      echo "read pls"
      case echo m.series {
        option.Some(Ok(srs)) -> {
          #(m, reader.continue_point(srs.id, ContinuePointRetrieved))
        }
        _ -> #(m, effect.none())
      }
    }
    ContinuePointRetrieved(Ok(cont_point)) -> {
      echo "continue retrieved"
      #(m, effect.none())
    }
    ContinuePointRetrieved(Error(_)) -> #(m, effect.none())
    RequestUpdate -> {
      echo "request update pls"
      #(m, effect.none())
    }
  }
}

fn view(m: Model) {
  case m.series {
    option.None -> element.none()
    option.Some(Error(_)) -> element.none()
    option.Some(Ok(series)) -> {
      case series.metadata {
        option.None -> element.none()
        option.Some(metadata) -> display(series, metadata)
      }
    }
  }
}

fn display(srs: series.Series, metadata: series.Metadata) {
  let new_time_range = date.get_time(date.now()) - 3 * { 24 * 60 * 60 * 1000 }
  let account = account.get()
  let cover_url =
    api.create_url(
      "/api/image/series-cover?seriesId="
      <> int.to_string(srs.id)
      <> "&apiKey="
      <> account.api_key,
    )

  html.div(
    [
      attribute.class(
        "font-[Poppins,sans-serif] max-w-screen-xl items-center justify-between mx-auto mb-8 p-4 space-y-4",
      ),
    ],
    [
      // editor(),
      html.div(
        [attribute.class("flex flex-col sm:flex-row md:flex-row gap-4")],
        [
          html.img([
            attribute.class("max-sm:self-center bg-zinc-800 rounded w-52 h-80"),
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
                    True ->
                      tag.simple("New!", [
                        attribute.class(
                          "bg-rose-600 normal-case! font-bold! text-[0.9rem]!",
                        ),
                      ])
                    False -> element.none()
                  },
                  html.h1([attribute.class("text-xl sm:text-5xl")], [
                    element.text(srs.localized_name),
                  ]),
                ],
              ),
              html.h2(
                [
                  attribute.class(
                    "font-medium sm:font-semibold text-lg sm:text-xl",
                  ),
                ],
                [element.text(srs.name)],
              ),
            ]),
            html.div([attribute.class("flex flex-wrap gap-2")], [
              button.button(
                [
                  event.on_click({
                    echo "clicked"
                    Read
                  }),
                  button.bg(button.Primary),
                  button.lg(),
                  attribute.class("font-semibold"),
                ],
                [
                  html.i([attribute.class("ph ph-book-open-text text-2xl")], []),
                  element.text(case srs.pages_read {
                    0 -> "Start Reading"
                    _ ->
                      case srs.pages_read == srs.pages {
                        False -> "Continue Reading"
                        True -> "Re-read"
                      }
                  }),
                ],
              ),
              button.button(
                [
                  event.on_click(RequestUpdate),
                  button.bg(button.Neutral),
                  button.lg(),
                  attribute.class("font-medium"),
                ],
                [
                  html.i(
                    [attribute.class("ph ph-clock-counter-clockwise text-2xl")],
                    [],
                  ),
                  element.text("Request Update"),
                ],
              ),
            ]),
            html.div(
              [attribute.class("flex flex-wrap gap-2")],
              list.append([tag.list(metadata.tags)], [
                html.span(
                  [
                    attribute.class("inline-flex items-center"),
                  ],
                  [
                    html.i(
                      [
                        attribute.class(
                          "ph-fill ph-circle "
                          <> case metadata.publication_status {
                            series.Ongoing -> "text-green-400"
                            series.Hiatus -> "text-orange-400"
                            series.Completed | series.Ended -> "text-sky-400"
                            series.Cancelled -> "text-red-400"
                            _ -> "text-gray-400"
                          },
                        ),
                      ],
                      [],
                    ),
                    tag.simple(
                      series.publication_title(metadata.publication_status),
                      [],
                    ),
                  ],
                ),
              ]),
            ),
          ]),
        ],
      ),
      // html.div([attribute.class("space-y-4")], [
    //   html.p([], [element.text(metadata.summary)]),
    //   html.div([attribute.class("flex flex-col gap-4")], [
    //     case list.is_empty(details.volumes) {
    //       True -> element.none()
    //       False ->
    //         html.div([attribute.class("space-y-4")], [
    //           html.h2([attribute.class("font-bold text-3xl")], [
    //             element.text("Volumes"),
    //           ]),
    //           html.div(
    //             [attribute.class("flex flex-col gap-2 w-full")],
    //             list.map(details.volumes, fn(vol: series.Volume) {
    //               button(
    //                 [
    //                   event.on_click(layout.Read(option.Some(vol.id))),
    //                   button.solid(button.Neutral),
    //                   button.lg(),
    //                   class("text-white font-semibold"),
    //                 ],
    //                 [
    //                   html.span([attribute.class("icon-book")], []),
    //                   element.text(vol.name),
    //                 ],
    //               )
    //             }),
    //           ),
    //         ])
    //     },
    //     {
    //       let chapters_from_vols =
    //         list.map(details.volumes, fn(vol: series.Volume) {
    //           list.map(vol.chapters, fn(chp: series.Chapter) {
    //             #(chp.id, True)
    //           })
    //         })
    //         |> list.flatten
    //         |> dict.from_list
    //       let filtered_chapters =
    //         list.filter(
    //           list.append(details.chapters, details.specials),
    //           fn(chp: series.Chapter) {
    //             bool.negate(dict.has_key(chapters_from_vols, chp.id))
    //           },
    //         )
    //       case list.is_empty(filtered_chapters) {
    //         True -> element.none()
    //         False ->
    //           html.div([attribute.class("space-y-4")], [
    //             html.div(
    //               [
    //                 attribute.class("flex flex-wrap gap-3 justify-between"),
    //               ],
    //               [
    //                 html.h2([attribute.class("font-bold text-3xl")], [
    //                   element.text("Chapters"),
    //                 ]),
    //                 button([button.solid(button.Neutral), button.md()], [
    //                   html.i(
    //                     [attribute.class("ph ph-sort-ascending text-2xl")],
    //                     [],
    //                   ),
    //                   element.text("Ascending"),
    //                 ]),
    //               ],
    //             ),
    //             html.div(
    //               [attribute.class("flex flex-col gap-2 w-ful")],
    //               list.map(
    //                 list.sort(
    //                   filtered_chapters,
    //                   fn(chp_a: series.Chapter, chp_b: series.Chapter) {
    //                     float.compare(chp_a.sort_order, chp_b.sort_order)
    //                   },
    //                 ),
    //                 fn(chp: series.Chapter) {
    //                   html.div([attribute.class("w-full group")], [
    //                     button(
    //                       [
    //                         event.on_click(layout.Read(option.Some(chp.id))),
    //                         button.solid(button.Neutral),
    //                         button.lg(),
    //                         class(
    //                           "group-hover:bg-zinc-700/60 w-full text-white font-semibold",
    //                         ),
    //                         case chp.pages_read {
    //                           0 -> attribute.none()
    //                           _ -> class("rounded-b-none")
    //                         },
    //                       ],
    //                       [
    //                         html.span([attribute.class("icon-book")], []),
    //                         element.text(chp.title),
    //                       ],
    //                     ),
    //                     case chp.pages_read {
    //                       0 -> element.none()
    //                       _ ->
    //                         html.div(
    //                           [
    //                             case chp.pages_read {
    //                               0 ->
    //                                 attribute.class(
    //                                   "group-hover:bg-zinc-700/60 bg-zinc-700",
    //                                 )
    //                               _ -> attribute.class("bg-zinc-800")
    //                             },
    //                             attribute.class("w-full rounded-b-md h-1"),
    //                           ],
    //                           [
    //                             html.div(
    //                               [
    //                                 case chp.pages_read == chp.pages {
    //                                   False ->
    //                                     attribute.class(
    //                                       "bg-violet-500 rounded-bl-md",
    //                                     )
    //                                   True ->
    //                                     attribute.class(
    //                                       "bg-emerald-500 rounded-b-lg",
    //                                     )
    //                                 },
    //                                 attribute.class("h-1"),
    //                                 attribute.style(
    //                                   "width",
    //                                   float.to_string(
    //                                     {
    //                                       int.to_float(chp.pages_read)
    //                                       /. int.to_float(chp.pages)
    //                                     }
    //                                     *. 100.0,
    //                                   )
    //                                     <> "%",
    //                                 ),
    //                               ],
    //                               [],
    //                             ),
    //                           ],
    //                         )
    //                     },
    //                   ])
    //                 },
    //               ),
    //             ),
    //           ])
    //       }
    //     },
    //   ]),
    // ]),
    ],
  )
}

fn editor() {
  html.div(
    [
      attribute.class(
        "bg-zinc-950/75 z-100 absolute inset-0 flex justify-center items-center",
      ),
    ],
    [
      html.div([attribute.class("p-4 bg-zinc-800 rounded-md h-1/3 w-[80%]")], [
        html.h1([attribute.class("font-bold text-lg")], [
          element.text("Edit Series"),
        ]),
        html.input([
          attribute.class(
            "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
          ),
        ]),
      ]),
    ],
  )
}
