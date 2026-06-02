import formal/form
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import lumiverse/api/account
import lumiverse/api/image_url
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
import plinth/browser/document
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
    new_tag_input: String,
    sort_ascending: Bool,
    active_tab: Tab,
  )
}

type SeriesEdit {
  SeriesEdit(series_name: String, localized_name: String, summary: String)
}

type Tab {
  StorylineTab
  VolumesTab
  ChaptersTab
}

type StorylineItem {
  StorylineVolume(vol: series.Volume, sort_key: Float)
  StorylineChapter(chp: series.Chapter)
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
  UpdateNewTagInput(String)
  SubmitNewTag
  RemoveTag(Int)
  ShowEditor(Bool)
  ToggleSort
  ReadChapter(Int)
  ReadVolume(series.Volume)
  SetTab(Tab)
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
      new_tag_input: "",
      sort_ascending: True,
      active_tab: StorylineTab,
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
      document.set_title(srs.name <> " | Lumiverse")
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
      case m.series {
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
    RequestUpdate -> #(m, effect.none())
    UpdateNewTagInput(value) -> #(
      Model(..m, new_tag_input: value),
      effect.none(),
    )
    SubmitNewTag ->
      case string.trim(m.new_tag_input) {
        "" -> #(m, effect.none())
        tag -> #(
          Model(..m, new_tag_input: ""),
          series.tags(fn(res) { TagsRetrieved(tag, res) }),
        )
      }
    TagsRetrieved(tag, Ok(tags)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, tags: [
          series.Tag(
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
    SetTab(active_tab) -> #(Model(..m, active_tab:), effect.none())
    ToggleSort -> #(
      Model(..m, sort_ascending: !m.sort_ascending),
      effect.none(),
    )
    ReadChapter(id) -> #(
      m,
      modem.push("/read/" <> int.to_string(id), option.None, option.None),
    )
    ReadVolume(vol) -> {
      let sorted =
        list.sort(vol.chapters, fn(a: series.Chapter, b) {
          float.compare(a.sort_order, b.sort_order)
        })
      let target =
        result.or(
          list.find(sorted, fn(c) { c.pages_read > 0 && c.pages_read < c.pages }),
          result.or(
            list.find(sorted, fn(c) { c.pages_read == 0 }),
            list.first(sorted),
          ),
        )
      case target {
        Error(_) -> #(m, effect.none())
        Ok(chp) -> #(
          m,
          modem.push(
            "/read/" <> int.to_string(chp.id),
            option.None,
            option.None,
          ),
        )
      }
    }
    EditSubmitted(Ok(edit_form)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, summary: edit_form.summary)
      let updated_series =
        series.Series(
          ..srs,
          name: edit_form.series_name,
          localized_name: edit_form.localized_name,
          metadata: option.Some(updated_metadata),
        )
      #(
        m,
        effect.batch([
          series.update_metadata(updated_metadata, MetadataUpdated),
          series.update(updated_series, fn(res) {
            case res {
              Ok(_) -> SeriesRetrieved(Ok(updated_series))
              Error(e) -> SeriesRetrieved(Error(e))
            }
          }),
        ]),
      )
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
  let cover_url = image_url.series_cover(srs.id, account |> account.image_key)

  html.div(
    [
      attribute.class("font-[Poppins,sans-serif] space-y-4 relative"),
    ],
    [
      html.div(
        [
          attribute.class(
            "absolute -top-4 -left-4 -right-4 h-72 sm:h-80 overflow-hidden pointer-events-none",
          ),
        ],
        [
          html.img([
            attribute.class(
              "absolute inset-0 w-full h-full object-cover blur-xl opacity-15 scale-110",
            ),
            attribute.src(cover_url),
            attribute.attribute("aria-hidden", "true"),
            attribute.attribute("fetchpriority", "low"),
          ]),
          html.div(
            [
              attribute.class(
                "absolute inset-0 bg-gradient-to-b from-zinc-950/20 to-zinc-950",
              ),
            ],
            [],
          ),
        ],
      ),
      case m.show_editor {
        False -> element.none()
        True -> editor(m, srs, metadata)
      },
      html.div(
        [attribute.class("relative z-10 flex flex-col sm:flex-row gap-4")],
        [
          html.img([
            attribute.class(
              "max-sm:self-center bg-zinc-800 rounded-lg h-64 sm:h-72 flex-shrink-0 object-cover shadow-2xl shadow-zinc-950",
            ),
            attribute.src(cover_url),
            attribute.rel("preload"),
            attribute.attribute("fetchpriority", "high"),
            attribute.attribute("as", "image"),
            attribute.alt("Cover image for " <> srs.localized_name),
          ]),
          html.div([attribute.class("flex flex-col gap-5 min-w-0")], [
            html.div([attribute.class("space-y-1")], [
              html.span(
                [
                  attribute.class(
                    "flex flex-nowrap gap-2 font-['Poppins'] font-extrabold items-center",
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
                    element.text(srs.name),
                  ]),
                ],
              ),
              case srs.localized_name == "" {
                False ->
                  html.h2(
                    [
                      attribute.class(
                        "font-medium text-zinc-400 text-base sm:text-lg",
                      ),
                    ],
                    [element.text(srs.localized_name)],
                  )
                True -> element.none()
              },
              html.div([attribute.class("flex items-center gap-2 flex-wrap")], [
                case metadata.release_year == 0 && metadata.language == "" {
                  True -> element.none()
                  False ->
                    html.span([attribute.class("text-sm text-zinc-400")], [
                      element.text(
                        [
                          case metadata.release_year {
                            0 -> ""
                            year -> int.to_string(year)
                          },
                          case metadata.language {
                            "" -> ""
                            lang -> lang
                          },
                        ]
                        |> list.filter(fn(s) { s != "" })
                        |> string.join(" · "),
                      ),
                    ])
                },
                case metadata.age_rating {
                  series.NotApplicable | series.UnknownRating -> element.none()
                  rating ->
                    html.span(
                      [
                        attribute.class(
                          "text-xs font-bold px-1.5 py-0.5 rounded w-fit "
                          <> age_rating_color(rating),
                        ),
                      ],
                      [element.text(age_rating_label(rating))],
                    )
                },
              ]),
              case srs.pages {
                0 -> element.none()
                total ->
                  html.div(
                    [
                      attribute.class(
                        "flex items-center gap-3 pt-1 w-48 sm:w-64",
                      ),
                    ],
                    [
                      html.div(
                        [
                          attribute.class(
                            "flex-1 h-1.5 bg-zinc-700 rounded-full overflow-hidden",
                          ),
                        ],
                        [
                          html.div(
                            [
                              attribute.class(case srs.pages_read == total {
                                True -> "h-full bg-emerald-500 rounded-full"
                                False -> "h-full bg-violet-500 rounded-full"
                              }),
                              attribute.style(
                                "width",
                                float.to_string(
                                  int.to_float(srs.pages_read)
                                  /. int.to_float(total)
                                  *. 100.0,
                                )
                                  <> "%",
                              ),
                            ],
                            [],
                          ),
                        ],
                      ),
                      html.span(
                        [attribute.class("text-xs text-zinc-400 shrink-0")],
                        [
                          element.text(
                            float.to_string(
                              {
                                {
                                  int.to_float(srs.pages_read)
                                  /. int.to_float(total)
                                }
                                *. 100.0
                              }
                              |> float.to_precision(2),
                            )
                            <> "% read",
                          ),
                        ],
                      ),
                    ],
                  )
              },
            ]),
            html.div([attribute.class("flex flex-wrap gap-2")], [
              button.icon_label(
                "ph ph-book-open-text text-2xl",
                case srs.pages_read {
                  0 -> "Start Reading"
                  _ ->
                    case srs.pages_read == srs.pages {
                      False -> "Continue"
                      True -> "Re-read"
                    }
                },
                [
                  event.on_click(Read),
                  button.primary(),
                  attribute.class("font-semibold"),
                ],
              ),
              // button.icon_label(
              //   "ph ph-clock-counter-clockwise text-2xl",
              //   "Request Update",
              //   [
              //     event.on_click(RequestUpdate),
              //     button.secondary(),
              //     attribute.class("font-medium"),
              //   ],
              // ),
              case m.admin {
                False -> element.none()
                True ->
                  button.icon("ph ph-pencil-simple-line text-2xl", [
                    event.on_click(ShowEditor(True)),
                    button.secondary(),
                    attribute.class("font-medium"),
                  ])
              },
            ]),
            html.div(
              [attribute.class("flex flex-wrap gap-2")],
              list.append(
                [
                  tag.list_with_function(
                    metadata.tags |> list.append(metadata.genres),
                    fn(t) {
                      [
                        event.on("dblclick", {
                          RemoveTag(t.id) |> decode.success
                        }),
                      ]
                    },
                  ),
                ],
                [
                  tag.element(
                    [
                      tag.color(""),
                      attribute.class("px-4"),
                      event.on_click(ShowEditor(True)),
                    ],
                    [
                      html.i(
                        [attribute.class("ph-bold ph-plus text-[1.1rem]")],
                        [],
                      ),
                    ],
                  ),
                  html.span([attribute.class("inline-flex items-center")], [
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
                      series.publication_title(metadata.publication_status)
                        |> string.capitalise,
                      [attribute.class("px-1!")],
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ],
      ),
      html.div(
        [
          attribute.class(
            "relative z-10 space-y-4 pt-2 border-t border-zinc-800",
          ),
        ],
        [
          html.div([attribute.class("space-y-3")], [
            html.h2([attribute.class("font-bold text-2xl")], [
              element.text("About"),
            ]),
            html.p([attribute.class("text-sm text-zinc-300 leading-relaxed")], [
              element.text(metadata.summary),
            ]),
          ]),
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
            let has_volumes = !list.is_empty(details.volumes)
            let has_chapters = !list.is_empty(filtered_chapters)
            let chp_sort = fn(a: series.Chapter, b: series.Chapter) {
              let cmp = float.compare(a.sort_order, b.sort_order)
              case m.sort_ascending {
                True -> cmp
                False -> order.negate(cmp)
              }
            }

            html.div([attribute.class("space-y-4")], [
              case has_volumes {
                False -> element.none()
                True ->
                  html.div(
                    [attribute.class("flex items-center justify-between")],
                    [
                      html.div(
                        [attribute.class("flex gap-4 border-b border-zinc-800")],
                        [
                          tab_button(
                            "Storyline",
                            m.active_tab == StorylineTab,
                            SetTab(StorylineTab),
                          ),
                          tab_button(
                            "Volumes",
                            m.active_tab == VolumesTab,
                            SetTab(VolumesTab),
                          ),
                          case has_chapters {
                            False -> element.none()
                            True ->
                              tab_button(
                                "Chapters",
                                m.active_tab == ChaptersTab,
                                SetTab(ChaptersTab),
                              )
                          },
                        ],
                      ),
                      button.icon_label(
                        case m.sort_ascending {
                          True -> "ph ph-sort-ascending text-2xl"
                          False -> "ph ph-sort-descending text-2xl"
                        },
                        case m.sort_ascending {
                          True -> "Ascending"
                          False -> "Descending"
                        },
                        [button.secondary(), event.on_click(ToggleSort)],
                      ),
                    ],
                  )
              },
              case m.active_tab {
                StorylineTab -> {
                  let vol_items =
                    list.map(details.volumes, fn(vol: series.Volume) {
                      let sort_key = case
                        list.sort(vol.chapters, fn(a: series.Chapter, b) {
                          float.compare(a.sort_order, b.sort_order)
                        })
                      {
                        [] -> 0.0
                        [first, ..] -> first.sort_order
                      }
                      StorylineVolume(vol, sort_key)
                    })
                  let chp_items =
                    list.map(filtered_chapters, fn(chp) {
                      StorylineChapter(chp)
                    })
                  let storyline =
                    list.sort(list.append(vol_items, chp_items), fn(a, b) {
                      let key_a = case a {
                        StorylineVolume(_, k) -> k
                        StorylineChapter(c) -> c.sort_order
                      }
                      let key_b = case b {
                        StorylineVolume(_, k) -> k
                        StorylineChapter(c) -> c.sort_order
                      }
                      let cmp = float.compare(key_a, key_b)
                      case m.sort_ascending {
                        True -> cmp
                        False -> order.negate(cmp)
                      }
                    })
                  html.div(
                    [attribute.class("flex flex-wrap gap-3")],
                    list.map(storyline, fn(item) {
                      case item {
                        StorylineVolume(vol, _) -> {
                          let pct = case vol.pages {
                            0 -> 0.0
                            p ->
                              int.to_float(vol.pages_read)
                              /. int.to_float(p)
                              *. 100.0
                          }
                          let chp_count = list.length(vol.chapters)
                          cover_card(
                            image_url.volume_cover(
                              vol.id,
                              account |> account.image_key,
                            ),
                            vol.name,
                            case chp_count > 1 {
                              True ->
                                option.Some(
                                  int.to_string(chp_count) <> " chapters",
                                )
                              False -> option.None
                            },
                            pct,
                            vol.pages_read == vol.pages && vol.pages > 0,
                            [event.on_click(ReadVolume(vol))],
                          )
                        }
                        StorylineChapter(chp) -> {
                          let pct = case chp.pages {
                            0 -> 0.0
                            p ->
                              int.to_float(chp.pages_read)
                              /. int.to_float(p)
                              *. 100.0
                          }
                          cover_card(
                            image_url.chapter_cover(
                              chp.id,
                              account |> account.image_key,
                            ),
                            chp.title,
                            option.None,
                            pct,
                            chp.pages_read == chp.pages && chp.pages > 0,
                            [event.on_click(ReadChapter(chp.id))],
                          )
                        }
                      }
                    }),
                  )
                }
                VolumesTab ->
                  html.div(
                    [attribute.class("flex flex-wrap gap-3")],
                    list.map(
                      list.sort(
                        details.volumes,
                        fn(a: series.Volume, b: series.Volume) {
                          let cmp = int.compare(a.max_number, b.max_number)
                          case m.sort_ascending {
                            True -> cmp
                            False -> order.negate(cmp)
                          }
                        },
                      ),
                      fn(vol: series.Volume) {
                        let pct = case vol.pages {
                          0 -> 0.0
                          p ->
                            int.to_float(vol.pages_read)
                            /. int.to_float(p)
                            *. 100.0
                        }
                        let chp_count = list.length(vol.chapters)
                        cover_card(
                          image_url.volume_cover(
                            vol.id,
                            account |> account.image_key,
                          ),
                          vol.name,
                          case chp_count > 1 {
                            True ->
                              option.Some(
                                int.to_string(chp_count) <> " chapters",
                              )
                            False -> option.None
                          },
                          pct,
                          vol.pages_read == vol.pages && vol.pages > 0,
                          [event.on_click(ReadVolume(vol))],
                        )
                      },
                    ),
                  )
                ChaptersTab ->
                  html.div(
                    [attribute.class("flex flex-wrap gap-3")],
                    list.map(
                      list.sort(filtered_chapters, chp_sort),
                      fn(chp: series.Chapter) {
                        let pct = case chp.pages {
                          0 -> 0.0
                          p ->
                            int.to_float(chp.pages_read)
                            /. int.to_float(p)
                            *. 100.0
                        }
                        cover_card(
                          image_url.chapter_cover(
                            chp.id,
                            account |> account.image_key,
                          ),
                          chp.title,
                          option.None,
                          pct,
                          chp.pages_read == chp.pages && chp.pages > 0,
                          [event.on_click(ReadChapter(chp.id))],
                        )
                      },
                    ),
                  )
              },
            ])
          },
        ],
      ),
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
            button.icon("ph ph-x text-2xl", [event.on_click(ShowEditor(False))]),
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
                html.div(
                  [attribute.class("inline-flex flex-wrap gap-2 mb-2")],
                  list.map(metadata.tags, fn(t) {
                    tag.single(t, [
                      attribute.class(
                        "active:bg-red-400/40 active:line-through",
                      ),
                      event.on_click(RemoveTag(t.id)),
                    ])
                  }),
                ),
                html.div([attribute.class("flex gap-2 items-center")], [
                  html.input([
                    attribute.class(
                      "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-2 border-zinc-600 focus:border-violet-600 text-sm",
                    ),
                    attribute.placeholder("Add tag…"),
                    attribute.value(m.new_tag_input),
                    event.on_input(UpdateNewTagInput),
                    event.on("keydown", {
                      use key <- decode.subfield(["key"], decode.string)
                      case key {
                        "Enter" -> decode.success(SubmitNewTag)
                        _ -> decode.failure(SubmitNewTag, "not enter")
                      }
                    }),
                  ]),
                  button.icon("ph ph-plus", [
                    attribute.type_("button"),
                    button.secondary(),
                    event.on_click(SubmitNewTag),
                  ]),
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
                  button.button("Submit", [button.primary()]),
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

fn tab_button(label: String, active: Bool, msg: Msg) {
  html.button(
    [
      attribute.class(
        "pb-2 px-1 text-sm font-medium border-b-2 -mb-px transition-colors "
        <> case active {
          True -> "border-violet-500 text-white"
          False -> "border-transparent text-zinc-400 hover:text-white"
        },
      ),
      event.on_click(msg),
    ],
    [element.text(label)],
  )
}

fn cover_card(
  cover_url: String,
  title: String,
  subtitle: option.Option(String),
  pct: Float,
  complete: Bool,
  attrs: List(attribute.Attribute(Msg)),
) {
  html.div(
    [attribute.class("w-28 sm:w-40 space-y-2 cursor-pointer group"), ..attrs],
    [
      html.img([
        attribute.class(
          "rounded bg-zinc-800 w-full object-cover h-40 sm:h-60 group-hover:brightness-110 transition",
        ),
        attribute.src(cover_url),
        attribute.attribute("loading", "lazy"),
        attribute.alt(title),
      ]),
      html.div([attribute.class("space-y-1")], [
        html.span([attribute.class("font-medium text-sm block")], [
          element.text(title),
        ]),
        case subtitle {
          option.None -> element.none()
          option.Some(s) ->
            html.span([attribute.class("text-xs text-zinc-400 block")], [
              element.text(s),
            ])
        },
        html.div(
          [attribute.class("h-1 bg-zinc-700 rounded-full overflow-hidden mt-1")],
          [
            html.div(
              [
                attribute.class(case complete {
                  True -> "h-full bg-emerald-500 rounded-full"
                  False -> "h-full bg-violet-500 rounded-full"
                }),
                attribute.style("width", float.to_string(pct) <> "%"),
              ],
              [],
            ),
          ],
        ),
      ]),
    ],
  )
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

fn age_rating_label(rating: series.AgeRating) -> String {
  case rating {
    series.RatingPending -> "Rating Pending"
    series.EarlyChildhood -> "Early Childhood"
    series.Everyone -> "Everyone"
    series.Everyone10Plus -> "Everyone 10+"
    series.Teen -> "Teen"
    series.Mature17Plus -> "Mature 17+"
    series.AdultsOnly -> "Adults Only"
    _ -> "Unknown"
  }
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
