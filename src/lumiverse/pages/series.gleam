import formal/form
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
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
import modem
import plinth/browser/window
import plinth/javascript/date
import rsvp

type Model {
  Model(
    id: Int,
    series: option.Option(Result(series.Series, rsvp.Error)),
    details: option.Option(series.Details),
    admin: Bool,
    show_editor: Bool,
    edit_form: form.Form(SeriesEdit),
  )
}

type SeriesEdit {
  SeriesEdit(series_name: String, localized_name: String, summary: String)
}

type Msg {
  SeriesID(Int)
  SeriesRetrieved(Result(series.Series, rsvp.Error))
  MetadataRetrieved(Result(series.Metadata, rsvp.Error))
  DetailsRetrieved(Result(series.Details, rsvp.Error))
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
  TagsRetrieved(String, Result(List(series.Tag), rsvp.Error))
  MetadataUpdated(Result(Nil, rsvp.Error))
  EditSubmitted(Result(SeriesEdit, form.Form(SeriesEdit)))
  Read
  RequestUpdate
  Admin(Bool)
  NewTag
  RemoveTag(Int)
  ShowEditor(Bool)
}

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("series-id", fn(value) {
        int.parse(value) |> result.map(SeriesID)
      }),
      component.on_property_change("admin", { decode.bool |> decode.map(Admin) }),
    ])
  lustre.register(app, "series-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "series-page",
    [attribute.class("flex w-full flex-col p-4"), ..attrs],
    [],
  )
}

pub fn id(id: String) {
  attribute.attribute("series-id", id)
}

fn init(_) {
  #(
    Model(
      id: 0,
      series: option.None,
      admin: False,
      show_editor: False,
      edit_form: editor_form(),
      details: option.None,
    ),
    effect.none(),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    Admin(admin) -> #(Model(..m, admin:), effect.none())
    SeriesID(id) -> #(
      Model(..m, id:),
      effect.batch([
        series.get(id, SeriesRetrieved),
        series.details(id, DetailsRetrieved),
      ]),
    )
    ShowEditor(show_editor) -> #(Model(..m, show_editor:), effect.none())
    SeriesRetrieved(Ok(srs)) -> {
      #(
        Model(..m, series: option.Some(Ok(srs))),
        series.metadata(srs.id, MetadataRetrieved),
      )
    }
    SeriesRetrieved(Error(e)) -> #(
      Model(..m, series: option.Some(Error(e))),
      effect.none(),
    )
    MetadataRetrieved(Ok(metadata)) -> {
      let assert option.Some(Ok(srs)) = m.series
      #(
        Model(
          ..m,
          series: option.Some(Ok(
            series.Series(..srs, metadata: option.Some(metadata)),
          )),
        ),
        effect.none(),
      )
    }
    MetadataRetrieved(Error(_)) -> #(m, effect.none())
    DetailsRetrieved(Ok(details)) -> #(
      Model(..m, details: option.Some(details)),
      effect.none(),
    )
    DetailsRetrieved(Error(_)) -> #(m, effect.none())
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
      #(
        m,
        modem.push(
          "/read/" <> cont_point.id |> int.to_string,
          option.None,
          option.None,
        ),
      )
    }
    ContinuePointRetrieved(Error(_)) -> #(m, effect.none())
    RequestUpdate -> {
      echo "request update pls"
      #(m, effect.none())
    }
    NewTag ->
      case window.prompt("Enter the tag name") {
        Error(_) -> #(m, effect.none())
        Ok(tag) -> #(m, series.tags(fn(res) { TagsRetrieved(tag, res) }))
      }
    TagsRetrieved(tag, Ok(tags)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, tags: [
          echo series.Tag(
            id: case
              tags
              |> list.find(fn(t) {
                t.title |> string.lowercase == tag |> string.lowercase
              })
            {
              Ok(t) -> t.id
              Error(_) ->
                case tags |> list.length {
                  0 -> 0
                  len -> len + 1
                }
            },
            title: tag,
          ),
          ..metadata.tags
        ])
      #(m, series.update_metadata(updated_metadata, MetadataUpdated))
    }
    RemoveTag(id) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(
          ..metadata,
          tags: metadata.tags
            |> list.filter(fn(t) { t.id != id }),
        )
      #(m, series.update_metadata(updated_metadata, MetadataUpdated))
    }
    MetadataUpdated(Ok(Nil)) -> #(m, series.metadata(m.id, MetadataRetrieved))
    TagsRetrieved(_, _) -> #(m, effect.none())
    MetadataUpdated(Error(_)) -> #(m, effect.none())
    EditSubmitted(Ok(edit_form)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, summary: edit_form.summary)
      #(m, series.update_metadata(updated_metadata, MetadataUpdated))
    }
    EditSubmitted(Error(edit_form)) -> #(Model(..m, edit_form:), effect.none())
  }
}

fn view(m: Model) {
  case m.series, m.details {
    option.Some(Ok(series)), option.Some(details) -> {
      case series.metadata {
        option.None -> element.none()
        option.Some(metadata) -> display(m, series, metadata, details)
      }
    }
    _, _ -> element.none()
  }
}

fn display(
  m: Model,
  srs: series.Series,
  metadata: series.Metadata,
  details: series.Details,
) {
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
      attribute.class("font-[Poppins,sans-serif] space-y-4"),
    ],
    [
      case m.show_editor {
        False -> element.none()
        True -> editor(m, srs, metadata)
      },
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
              case m.admin {
                False -> element.none()
                True ->
                  button.button(
                    [
                      event.on_click(ShowEditor(True)),
                      button.bg(button.Neutral),
                      button.md(),
                      attribute.class("font-medium"),
                    ],
                    [
                      html.i(
                        [attribute.class("ph ph-pencil-simple-line text-2xl")],
                        [],
                      ),
                    ],
                  )
              },
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
                    button.button(
                      [
                        // event.on_click(layout.Read(option.Some(vol.id))),
                        button.bg(button.Neutral),
                        button.lg(),
                        attribute.class("text-white font-semibold"),
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
                  html.div(
                    [
                      attribute.class("flex flex-wrap gap-3 justify-between"),
                    ],
                    [
                      html.h2([attribute.class("font-bold text-3xl")], [
                        element.text("Chapters"),
                      ]),
                      button.button([button.bg(button.Neutral), button.md()], [
                        html.i(
                          [attribute.class("ph ph-sort-ascending text-2xl")],
                          [],
                        ),
                        element.text("Ascending"),
                      ]),
                    ],
                  ),
                  html.div(
                    [attribute.class("flex flex-col gap-2 w-ful")],
                    list.map(
                      list.sort(
                        filtered_chapters,
                        fn(chp_a: series.Chapter, chp_b: series.Chapter) {
                          float.compare(chp_a.sort_order, chp_b.sort_order)
                        },
                      ),
                      fn(chp: series.Chapter) {
                        html.div([attribute.class("w-full group")], [
                          button.button(
                            [
                              // event.on_click(layout.Read(option.Some(chp.id))),
                              button.bg(button.Neutral),
                              button.lg(),
                              attribute.class(
                                "group-hover:bg-zinc-700/60 w-full text-white font-semibold",
                              ),
                              case chp.pages_read {
                                0 -> attribute.none()
                                _ -> attribute.class("rounded-b-none")
                              },
                            ],
                            [
                              html.span([attribute.class("icon-book")], []),
                              element.text(chp.title),
                            ],
                          ),
                          case chp.pages_read {
                            0 -> element.none()
                            _ ->
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
                                      case chp.pages_read == chp.pages {
                                        False ->
                                          attribute.class(
                                            "bg-violet-500 rounded-bl-md",
                                          )
                                        True ->
                                          attribute.class(
                                            "bg-emerald-500 rounded-b-lg",
                                          )
                                      },
                                      attribute.class("h-1"),
                                      attribute.style(
                                        "width",
                                        float.to_string(
                                          {
                                            int.to_float(chp.pages_read)
                                            /. int.to_float(chp.pages)
                                          }
                                          *. 100.0,
                                        )
                                          <> "%",
                                      ),
                                    ],
                                    [],
                                  ),
                                ],
                              )
                          },
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
  )
}

fn editor(m: Model, srs: series.Series, metadata: series.Metadata) {
  let submit = fn(fields) {
    editor_form()
    |> form.add_values(fields)
    |> form.run
    |> EditSubmitted
  }

  html.div(
    [
      attribute.class(
        "bg-zinc-950/75 z-100 absolute inset-0 flex justify-center items-center",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex flex-col p-4 gap-2 bg-zinc-800 rounded-md h-[50%] w-[50%]",
          ),
        ],
        [
          html.div([attribute.class("flex justify-between items-center")], [
            html.h1([attribute.class("font-bold text-2xl")], [
              element.text("Edit Series"),
            ]),
            button.button([event.on_click(ShowEditor(False))], [
              html.i([attribute.class("ph ph-x text-2xl")], []),
            ]),
          ]),
          html.form(
            [
              attribute.class(
                "flex-1 h-full flex flex-col gap-4 pr-4 overflow-y-auto",
              ),
              event.on_submit(submit),
            ],
            [
              html.div([attribute.class("space-y-2")], [
                label("series_name", "Series Name"),
                html.input([
                  attribute.class(
                    "w-fit bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
                  ),
                  attribute.name("series_name"),
                  attribute.value(srs.name),
                ]),
              ]),
              html.div([attribute.class("space-y-2")], [
                label("localized_name", "Localized Name"),
                html.input([
                  attribute.class(
                    "w-fit bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
                  ),
                  attribute.name("localized_name"),
                  attribute.value(srs.localized_name),
                ]),
              ]),
              html.div([attribute.class("space-y-2")], [
                label("tags", "Tags"),
                html.div([attribute.class("flex gap-2 items-center")], [
                  html.div(
                    [attribute.class("inline-flex flex-wrap gap-2")],
                    list.map(metadata.tags, fn(t) {
                      tag.single(t, [
                        attribute.class(
                          "active:bg-red-400/40 active:line-through",
                        ),
                        event.on_click(RemoveTag(t.id)),
                      ])
                    }),
                  ),
                  tag.element(
                    [
                      attribute.class("bg-zinc-500 px-2"),
                      event.on_click(NewTag),
                    ],
                    [
                      html.i(
                        [attribute.class("ph-bold ph-plus text-[1rem]")],
                        [],
                      ),
                    ],
                  ),
                ]),
                html.div([attribute.class("space-y-2 w-full")], [
                  label("summary", "Summary"),
                  html.textarea(
                    [
                      attribute.class(
                        "w-full h-24 text-xs bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none resize-none border-b-5 border-zinc-700 focus:border-violet-600",
                      ),
                      attribute.name("summary"),
                    ],
                    metadata.summary,
                  ),
                ]),
                html.div([attribute.class("pt-2 sticky bottom-0 bg-zinc-800")], [
                  button.button(
                    [
                      button.lg(),
                      button.bg(button.Primary),
                    ],
                    [
                      element.text("Submit"),
                    ],
                  ),
                ]),
              ]),
            ],
          ),
        ],
      ),
    ],
  )
}

fn editor_form() {
  form.new({
    use series_name <- form.field(
      "series_name",
      form.parse_string |> form.check_not_empty,
    )
    use localized_name <- form.field(
      "localized_name",
      form.parse_string |> form.check_not_empty,
    )
    use summary <- form.field(
      "summary",
      form.parse_string |> form.check_not_empty,
    )
    form.success(SeriesEdit(series_name:, localized_name:, summary:))
  })
}

fn label(for: String, title: String) {
  html.label(
    [
      attribute.for(for),
      attribute.class("block text-md text-zinc-300"),
    ],
    [
      element.text(title),
    ],
  )
}
