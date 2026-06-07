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
import lumiverse/elements/series as series_element
import lumiverse/elements/tag
import lumiverse/pages/error
import lumiverse/pages/series/editor
import lumiverse/pages/series/model.{type Model, type Msg, Model}
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

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("series-id", fn(value) {
        int.parse(value) |> result.map(model.SeriesID)
      }),
      component.on_property_change("admin", {
        decode.bool |> decode.map(model.Admin)
      }),
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
      details: option.None,
      time_left: option.None,
      admin: False,
      sort_ascending: True,
      active_tab: model.StorylineTab,
      loading_reader: False,
      show_editor: False,
      editor_section: model.BasicInfoSection,
      new_tag_input: "",
      new_genre_input: "",
      basic_form: editor.basic_info_form(),
      details_form: editor.details_form(),
    ),
    effect.none(),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    model.Admin(admin) -> #(Model(..m, admin:), effect.none())
    model.SeriesID(id) -> #(
      Model(..m, id:),
      series.get(id, model.SeriesRetrieved),
    )
    model.SeriesRetrieved(Ok(srs)) -> {
      document.set_title(srs.name <> " | Lumiverse")
      #(
        Model(..m, series: option.Some(Ok(srs))),
        effect.batch([
          series.metadata(srs.id, model.MetadataRetrieved),
          series.details(srs.id, model.DetailsRetrieved),
          series.time_left(srs.id, model.TimeLeftRetrieved),
        ]),
      )
    }
    model.SeriesRetrieved(Error(e)) -> #(
      Model(..m, series: option.Some(Error(e))),
      effect.none(),
    )
    model.MetadataRetrieved(Ok(metadata)) -> {
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
    model.MetadataRetrieved(Error(_)) -> #(m, effect.none())
    model.DetailsRetrieved(Ok(details)) -> #(
      Model(..m, details: option.Some(details)),
      effect.none(),
    )
    model.DetailsRetrieved(Error(_)) -> #(m, effect.none())
    model.TimeLeftRetrieved(Ok(t)) -> #(
      Model(..m, time_left: option.Some(t)),
      effect.none(),
    )
    model.TimeLeftRetrieved(Error(_)) -> #(m, effect.none())
    model.Read ->
      case m.series {
        option.Some(Ok(srs)) -> #(
          Model(..m, loading_reader: True),
          reader.continue_point(srs.id, model.ContinuePointRetrieved),
        )
        _ -> #(m, effect.none())
      }
    model.ContinuePointRetrieved(Ok(cont_point)) -> #(
      Model(..m, loading_reader: False),
      modem.push(
        "/read/" <> cont_point.id |> int.to_string,
        option.None,
        option.None,
      ),
    )
    model.ContinuePointRetrieved(Error(_)) -> #(m, effect.none())
    model.SetTab(active_tab) -> #(Model(..m, active_tab:), effect.none())
    model.ToggleSort -> #(
      Model(..m, sort_ascending: !m.sort_ascending),
      effect.none(),
    )
    model.ReadChapter(id) -> #(
      m,
      modem.push("/read/" <> int.to_string(id), option.None, option.None),
    )
    model.ReadVolume(vol) -> {
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
    _ -> editor.update(m, msg)
  }
}

fn view(m: Model) {
  case m.series {
    option.Some(Error(_)) -> error.page(error.NotFound)
    option.Some(Ok(srs)) ->
      case srs.metadata, m.details {
        option.Some(metadata), option.Some(details) ->
          display(m, srs, metadata, details)
        _, _ -> loading_display(option.Some(srs))
      }
    option.None -> loading_display(option.None)
  }
}

fn loading_display(srs: option.Option(series.Series)) {
  let account = account.get()
  let api_key = account |> account.image_key
  html.div([attribute.class("font-[Poppins,sans-serif] space-y-4 relative")], [
    html.div(
      [
        attribute.class(
          "absolute -top-4 -left-4 -right-4 h-72 sm:h-80 overflow-hidden pointer-events-none",
        ),
      ],
      [
        case srs {
          option.Some(s) ->
            html.img([
              attribute.class(
                "absolute inset-0 w-full h-full object-cover blur-xl opacity-15 scale-110",
              ),
              attribute.src(image_url.series_cover_blur(s.id, api_key)),
              attribute.alt(""),
              attribute.attribute("aria-hidden", "true"),
              attribute.attribute("fetchpriority", "low"),
            ])
          option.None -> element.none()
        },
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
    html.div(
      [attribute.class("relative z-10 flex flex-col sm:flex-row gap-4")],
      [
        case srs {
          option.Some(s) ->
            html.img([
              attribute.class(
                "max-sm:self-center bg-zinc-800 rounded-lg h-64 sm:h-72 aspect-[2/3] flex-shrink-0 object-cover shadow-2xl shadow-zinc-950",
              ),
              attribute.src(image_url.series_cover_w(s.id, api_key, 800)),
              attribute.attribute("fetchpriority", "high"),
              attribute.alt(""),
            ])
          option.None ->
            html.div(
              [
                attribute.class(
                  "max-sm:self-center bg-zinc-800 rounded-lg h-64 sm:h-72 aspect-[2/3] flex-shrink-0 animate-pulse",
                ),
              ],
              [],
            )
        },
        html.div([attribute.class("flex flex-col gap-2 min-w-0 flex-1")], [
          html.div(
            [
              attribute.class(
                "h-10 sm:h-14 w-3/4 bg-zinc-800 rounded animate-pulse",
              ),
            ],
            [],
          ),
          html.div(
            [attribute.class("h-4 w-1/2 bg-zinc-800 rounded animate-pulse")],
            [],
          ),
          html.div(
            [attribute.class("h-3.5 w-32 bg-zinc-800 rounded animate-pulse")],
            [],
          ),
          html.div(
            [attribute.class("h-9 w-36 bg-zinc-800 rounded-lg animate-pulse")],
            [],
          ),
        ]),
      ],
    ),
    html.div([attribute.class("relative z-10 space-y-3 pt-2")], [
      html.div(
        [attribute.class("h-5 w-16 bg-zinc-800 rounded animate-pulse")],
        [],
      ),
      html.div(
        [attribute.class("h-4 w-full bg-zinc-800 rounded animate-pulse")],
        [],
      ),
      html.div(
        [attribute.class("h-4 w-5/6 bg-zinc-800 rounded animate-pulse")],
        [],
      ),
      html.div(
        [attribute.class("h-4 w-4/6 bg-zinc-800 rounded animate-pulse")],
        [],
      ),
    ]),
  ])
}

fn display(
  m: Model,
  srs: series.Series,
  metadata: series.Metadata,
  details: series.Details,
) {
  let new_time_range = date.get_time(date.now()) - 3 * { 24 * 60 * 60 * 1000 }
  let account = account.get()
  let api_key = account |> account.image_key
  let cover_url = image_url.series_cover_w(srs.id, api_key, 800)
  let blur_url = image_url.series_cover_blur(srs.id, api_key)

  html.div(
    [attribute.class("font-[Poppins,sans-serif] flex flex-col gap-4 relative")],
    [
      background_blur(blur_url),
      editor.panel(m),
      series_header(m, srs, metadata, new_time_range, cover_url),
      html.div(
        [
          attribute.class(
            "relative z-10 space-y-4 pt-2 border-t border-zinc-800",
          ),
        ],
        [about_section(metadata), content_tabs(m, details, api_key)],
      ),
    ],
  )
}

fn background_blur(blur_url: String) -> element.Element(Msg) {
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
        attribute.src(blur_url),
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
  )
}

fn series_header(
  m: Model,
  srs: series.Series,
  metadata: series.Metadata,
  new_time_range: Int,
  cover_url: String,
) -> element.Element(Msg) {
  html.div([attribute.class("relative z-10 flex flex-col sm:flex-row gap-4")], [
    html.img([
      attribute.class(
        "max-sm:self-center bg-zinc-800 rounded-lg h-64 sm:h-72 aspect-[2/3] flex-shrink-0 object-cover shadow-2xl shadow-zinc-950",
      ),
      attribute.src(cover_url),
      attribute.rel("preload"),
      attribute.attribute("fetchpriority", "high"),
      attribute.attribute("as", "image"),
      attribute.alt("Cover image for " <> srs.localized_name),
    ]),
    html.div([attribute.class("flex flex-col gap-2 min-w-0")], [
      title_block(srs, metadata, new_time_range, m.time_left),
      progress_bar(srs),
      action_buttons(m),
      tags_bar(metadata),
    ]),
  ])
}

fn title_block(
  srs: series.Series,
  metadata: series.Metadata,
  new_time_range: Int,
  time_left: option.Option(series.Time),
) -> element.Element(Msg) {
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
          [attribute.class("font-medium text-zinc-400 text-base sm:text-lg")],
          [element.text(srs.localized_name)],
        )
      True -> element.none()
    },
    html.div([attribute.class("flex items-center gap-2 flex-wrap")], [
      case metadata.age_rating {
        series.NotApplicable | series.UnknownRating -> element.none()
        rating -> series_element.age_rating(rating, [])
      },
      case time_left {
        option.None -> element.none()
        option.Some(t) ->
          html.span([attribute.class("text-sm text-zinc-400")], [
            element.text(case t.average_hours >. 0.0 {
              True ->
                "~"
                <> {
                  t.average_hours
                  |> float.ceiling
                  |> float.truncate
                  |> int.to_string
                }
                <> " hrs left"
              False -> int.to_string(t.page_count) <> " pages left"
            }),
          ])
      },
    ]),
  ])
}

fn progress_bar(srs: series.Series) -> element.Element(Msg) {
  case srs.pages {
    0 -> element.none()
    total ->
      html.div([attribute.class("flex items-center gap-3 pt-1 w-48 sm:w-64")], [
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
                    int.to_float(srs.pages_read) /. int.to_float(total) *. 100.0,
                  )
                    <> "%",
                ),
              ],
              [],
            ),
          ],
        ),
        html.span([attribute.class("text-xs text-zinc-400 shrink-0")], [
          element.text(
            float.to_string(
              { int.to_float(srs.pages_read) /. int.to_float(total) *. 100.0 }
              |> float.to_precision(2),
            )
            <> "% read",
          ),
        ]),
      ])
  }
}

fn action_buttons(m: Model) -> element.Element(Msg) {
  let assert option.Some(Ok(srs)) = m.series
  html.div([attribute.class("flex flex-wrap gap-2")], [
    button.icon_label(
      "ph ph-[book-open-text] text-2xl",
      case srs.pages_read {
        0 -> "Start Reading"
        _ ->
          case srs.pages_read == srs.pages {
            False -> "Continue"
            True -> "Re-read"
          }
      },
      [
        event.on_click(model.Read),
        button.primary(),
        attribute.class("font-semibold"),
      ],
    ),
    case m.admin {
      False -> element.none()
      True ->
        button.icon("ph ph-[pencil-simple-line] text-2xl", "Edit series", [
          event.on_click(model.ShowEditor(True)),
          button.secondary(),
          attribute.class("font-medium"),
        ])
    },
  ])
}

fn tags_bar(metadata: series.Metadata) -> element.Element(Msg) {
  html.div(
    [attribute.class("flex flex-wrap gap-2")],
    [
      publication_status(metadata),
      ..list.map(
        tag.sort_reverse(metadata.tags |> list.append(metadata.genres)),
        fn(t) { tag.single(t, []) },
      )
    ]
      |> list.reverse,
  )
}

fn publication_status(metadata: series.Metadata) -> element.Element(Msg) {
  html.span([attribute.class("inline-flex items-center gap-1")], [
    html.i(
      [
        attribute.class("ph ph-[circle--fill]"),
        attribute.class(case metadata.publication_status {
          series.Ongoing -> "text-green-400"
          series.Hiatus -> "text-orange-400"
          series.Completed | series.Ended -> "text-sky-400"
          series.Cancelled -> "text-red-400"
          _ -> "text-gray-400"
        }),
      ],
      [],
    ),
    html.span([attribute.class(tag.tag_appearance)], [
      case metadata.release_year {
        0 -> element.none()
        year -> element.text(int.to_string(year) <> ", ")
      },
      element.text(series.publication_label(metadata.publication_status)),
    ]),
  ])
}

fn about_section(metadata: series.Metadata) -> element.Element(Msg) {
  html.div([attribute.class("space-y-3")], [
    html.h2([attribute.class("font-bold text-2xl")], [element.text("About")]),
    html.p([attribute.class("text-sm text-zinc-300 leading-relaxed")], [
      element.text(metadata.summary),
    ]),
  ])
}

fn content_tabs(
  m: Model,
  details: series.Details,
  api_key: String,
) -> element.Element(Msg) {
  let filtered_chapters = filtered_chapters(details)
  let has_volumes = !list.is_empty(details.volumes)
  let has_chapters = !list.is_empty(filtered_chapters)

  html.div([attribute.class("space-y-4")], [
    case has_volumes {
      False -> element.none()
      True -> tab_bar(m, has_volumes, has_chapters)
    },
    case m.active_tab {
      model.StorylineTab ->
        storyline_tab(m, details, filtered_chapters, api_key)
      model.VolumesTab -> volumes_tab(m, details, api_key)
      model.ChaptersTab -> chapters_tab(m, filtered_chapters, api_key)
    },
  ])
}

fn filtered_chapters(details: series.Details) -> List(series.Chapter) {
  let chapters_from_vols =
    list.map(details.volumes, fn(vol: series.Volume) {
      list.map(vol.chapters, fn(chp: series.Chapter) { #(chp.id, True) })
    })
    |> list.flatten
    |> dict.from_list
  list.filter(
    list.append(details.chapters, details.specials),
    fn(chp: series.Chapter) {
      bool.negate(dict.has_key(chapters_from_vols, chp.id))
    },
  )
}

fn tab_bar(
  m: Model,
  has_volumes: Bool,
  has_chapters: Bool,
) -> element.Element(Msg) {
  html.div([attribute.class("flex items-center justify-between")], [
    html.div([attribute.class("flex gap-4 border-b border-zinc-800")], [
      tab_button(
        "Storyline",
        m.active_tab == model.StorylineTab,
        model.SetTab(model.StorylineTab),
      ),
      case has_volumes {
        False -> element.none()
        True ->
          tab_button(
            "Volumes",
            m.active_tab == model.VolumesTab,
            model.SetTab(model.VolumesTab),
          )
      },
      case has_chapters {
        False -> element.none()
        True ->
          tab_button(
            "Chapters",
            m.active_tab == model.ChaptersTab,
            model.SetTab(model.ChaptersTab),
          )
      },
    ]),
    button.icon_label(
      case m.sort_ascending {
        True -> "ph ph-[sort-ascending] text-2xl"
        False -> "ph ph-[sort-descending] text-2xl"
      },
      case m.sort_ascending {
        True -> "Ascending"
        False -> "Descending"
      },
      [button.secondary(), event.on_click(model.ToggleSort)],
    ),
  ])
}

fn storyline_tab(
  m: Model,
  details: series.Details,
  filtered_chapters: List(series.Chapter),
  api_key: String,
) -> element.Element(Msg) {
  let vol_items =
    list.map(details.volumes, fn(vol: series.Volume) {
      model.StorylineVolume(vol, vol.max_number |> int.to_float)
    })
  let chp_items = list.map(filtered_chapters, model.StorylineChapter)
  let storyline =
    list.sort(list.append(vol_items, chp_items), fn(a, b) {
      let key_a = case a {
        model.StorylineVolume(_, k) -> k
        model.StorylineChapter(c) -> c.sort_order
      }
      let key_b = case b {
        model.StorylineVolume(_, k) -> k
        model.StorylineChapter(c) -> c.sort_order
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
        model.StorylineVolume(vol, _) -> {
          let pct = case vol.pages {
            0 -> 0.0
            p -> int.to_float(vol.pages_read) /. int.to_float(p) *. 100.0
          }
          let chp_count = list.length(vol.chapters)
          cover_card(
            image_url.volume_cover(vol.id, api_key),
            vol.name,
            case chp_count > 1 {
              True -> option.Some(int.to_string(chp_count) <> " chapters")
              False -> option.None
            },
            pct,
            vol.pages_read == vol.pages && vol.pages > 0,
            [event.on_click(model.ReadVolume(vol))],
          )
        }
        model.StorylineChapter(chp) -> {
          let pct = case chp.pages {
            0 -> 0.0
            p -> int.to_float(chp.pages_read) /. int.to_float(p) *. 100.0
          }
          cover_card(
            image_url.chapter_cover(chp.id, api_key),
            chp.title,
            option.None,
            pct,
            chp.pages_read == chp.pages && chp.pages > 0,
            [event.on_click(model.ReadChapter(chp.id))],
          )
        }
      }
    }),
  )
}

fn volumes_tab(
  m: Model,
  details: series.Details,
  api_key: String,
) -> element.Element(Msg) {
  html.div(
    [attribute.class("flex flex-wrap gap-3")],
    list.map(
      list.sort(details.volumes, fn(a: series.Volume, b: series.Volume) {
        let cmp = int.compare(a.max_number, b.max_number)
        case m.sort_ascending {
          True -> cmp
          False -> order.negate(cmp)
        }
      }),
      fn(vol: series.Volume) {
        let pct = case vol.pages {
          0 -> 0.0
          p -> int.to_float(vol.pages_read) /. int.to_float(p) *. 100.0
        }
        let chp_count = list.length(vol.chapters)
        cover_card(
          image_url.volume_cover(vol.id, api_key),
          vol.name,
          case chp_count > 1 {
            True -> option.Some(int.to_string(chp_count) <> " chapters")
            False -> option.None
          },
          pct,
          vol.pages_read == vol.pages && vol.pages > 0,
          [event.on_click(model.ReadVolume(vol))],
        )
      },
    ),
  )
}

fn chapters_tab(
  m: Model,
  filtered_chapters: List(series.Chapter),
  api_key: String,
) -> element.Element(Msg) {
  let chp_sort = fn(a: series.Chapter, b: series.Chapter) {
    let cmp = float.compare(a.sort_order, b.sort_order)
    case m.sort_ascending {
      True -> cmp
      False -> order.negate(cmp)
    }
  }
  html.div(
    [attribute.class("flex flex-wrap gap-3")],
    list.map(list.sort(filtered_chapters, chp_sort), fn(chp: series.Chapter) {
      let pct = case chp.pages {
        0 -> 0.0
        p -> int.to_float(chp.pages_read) /. int.to_float(p) *. 100.0
      }
      cover_card(
        image_url.chapter_cover(chp.id, api_key),
        chp.title,
        option.None,
        pct,
        chp.pages_read == chp.pages && chp.pages > 0,
        [event.on_click(model.ReadChapter(chp.id))],
      )
    }),
  )
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
