import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/javascript/array
import gleam/json
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/uri
import localstorage
import lumiverse/api/account
import lumiverse/api/image_url
import lumiverse/api/reader
import lumiverse/api/series
import lumiverse/elements/button
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import plinth/browser/document
import plinth/browser/element as plinth_element
import plinth/browser/shadow
import plinth/browser/window
import rsvp

@external(javascript, "./reader_ffi.mjs", "eventKey")
fn event_key(event: a) -> String

@external(javascript, "./reader_ffi.mjs", "scrollBy")
fn do_scroll_by(amount: Int) -> Nil

fn range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range(from + 1, to)]
  }
}

pub type Direction {
  LTR
  RTL
}

pub type FitMode {
  FitWidth
  FitHeight
  Original
}

pub type ReadingMode {
  PageByPage
  LongStrip
}

pub type ReaderPrefs {
  ReaderPrefs(
    direction: Direction,
    fit_mode: FitMode,
    zoom: Int,
    scroll_speed: Int,
    preload_count: Int,
  )
}

pub type Model {
  Model(
    id: Int,
    loading: Bool,
    progress: option.Option(Result(reader.Progress, rsvp.Error)),
    cont_point: option.Option(reader.ContinuePoint),
    next_chapter: option.Option(Int),
    prev_chapter: option.Option(Int),
    chapter_info: option.Option(reader.ChapterInfo),
    image_loaded: Bool,
    show_hint: Bool,
    show_settings: Bool,
    reading_mode: ReadingMode,
    prefs: ReaderPrefs,
    zen: Bool,
    editing_page: Bool,
    header_hovered: Bool,
    scrubber_hovered: Bool,
  )
}

pub type Msg {
  ID(Int)
  Next
  Previous
  NavigateRight
  NavigateLeft
  GoToPage(Int)
  EditPage
  ConfirmPageEdit(String)
  HeaderHover(Bool)
  ProgressUpdate(Result(Nil, rsvp.Error))
  PreviousChapter(Result(Int, rsvp.Error))
  NextChapter(Result(Int, rsvp.Error))
  ProgressRetrieved(Result(reader.Progress, rsvp.Error))
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
  ChapterInfoRetrieved(Result(reader.ChapterInfo, rsvp.Error))
  SeriesMetadataRetrieved(Result(series.Metadata, rsvp.Error))
  PageLoaded
  DismissHint
  ToggleSettings
  ToggleZen
  SyncZen(Bool)
  SetDirection(Direction)
  SetFitMode(FitMode)
  SetZoom(Int)
  SetScrollSpeed(Int)
  SetPreloadCount(Int)
  SetReadingMode(ReadingMode)
  ScrollUp
  ScrollDown
  ScrubberHover(Bool)
}

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("chapter-id", fn(value) {
        int.parse(value) |> result.map(ID)
      }),
    ])
  lustre.register(app, "reader-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "reader-page",
    [attribute.class("w-full h-screen block"), ..attrs],
    [],
  )
}

pub fn id(id: String) {
  attribute.attribute("chapter-id", id)
}

fn default_prefs() -> ReaderPrefs {
  ReaderPrefs(
    direction: LTR,
    fit_mode: FitWidth,
    zoom: 100,
    scroll_speed: 300,
    preload_count: 3,
  )
}

fn load_prefs() -> ReaderPrefs {
  case localstorage.read("reader_prefs") {
    Error(_) -> default_prefs()
    Ok(s) ->
      case json.parse(s, prefs_decoder()) {
        Ok(p) -> p
        Error(_) -> default_prefs()
      }
  }
}

fn save_prefs_effect(prefs: ReaderPrefs) -> effect.Effect(Msg) {
  effect.from(fn(_) {
    localstorage.write("reader_prefs", prefs |> prefs_to_json |> json.to_string)
    Nil
  })
}

fn prefs_to_json(p: ReaderPrefs) -> json.Json {
  json.object([
    #(
      "direction",
      json.string(case p.direction {
        LTR -> "ltr"
        RTL -> "rtl"
      }),
    ),
    #(
      "fit_mode",
      json.string(case p.fit_mode {
        FitWidth -> "width"
        FitHeight -> "height"
        Original -> "original"
      }),
    ),
    #("zoom", json.int(p.zoom)),
    #("scroll_speed", json.int(p.scroll_speed)),
    #("preload_count", json.int(p.preload_count)),
  ])
}

fn prefs_decoder() {
  use direction <- decode.field("direction", {
    use s <- decode.then(decode.string)
    decode.success(case s {
      "rtl" -> RTL
      _ -> LTR
    })
  })
  use fit_mode <- decode.field("fit_mode", {
    use s <- decode.then(decode.string)
    decode.success(case s {
      "height" -> FitHeight
      "original" -> Original
      _ -> FitWidth
    })
  })
  use zoom <- decode.field("zoom", decode.int)
  use scroll_speed <- decode.field("scroll_speed", decode.int)
  use preload_count <- decode.field("preload_count", decode.int)
  decode.success(ReaderPrefs(
    direction:,
    fit_mode:,
    zoom:,
    scroll_speed:,
    preload_count:,
  ))
}

pub fn init(_) {
  let prefs = load_prefs()
  let show_hint = localstorage.read("reader_hint_seen") |> result.is_error
  #(
    Model(
      id: 0,
      loading: True,
      progress: option.None,
      cont_point: option.None,
      prev_chapter: option.None,
      next_chapter: option.None,
      chapter_info: option.None,
      image_loaded: False,
      show_hint:,
      show_settings: False,
      reading_mode: PageByPage,
      prefs:,
      zen: False,
      editing_page: False,
      header_hovered: False,
      scrubber_hovered: False,
    ),
    effect.batch([
      setup_keyboard_listener(),
      setup_fullscreen_listener(),
    ]),
  )
}

fn setup_keyboard_listener() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    document.add_event_listener("keydown", fn(raw) {
      case event_key(raw) {
        "ArrowRight" | "d" | "l" -> dispatch(NavigateRight)
        "ArrowLeft" | "a" | "h" -> dispatch(NavigateLeft)
        "ArrowUp" | "w" -> dispatch(ScrollUp)
        "ArrowDown" | "s" -> dispatch(ScrollDown)
        "z" -> dispatch(ToggleZen)
        _ -> Nil
      }
    })
    Nil
  })
}

fn setup_fullscreen_listener() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    document.add_event_listener("fullscreenchange", fn(_) {
      let doc = window.document(window.self())
      let is_fullscreen = document.fullscreen_element(doc) |> result.is_ok
      dispatch(SyncZen(is_fullscreen))
    })
    Nil
  })
}

pub fn update(m: Model, msg: Msg) {
  case msg {
    ID(id) -> #(Model(..m, id:), reader.progress(id, ProgressRetrieved))
    ProgressRetrieved(Ok(progress)) -> #(
      Model(..m, progress: option.Some(Ok(progress))),
      reader.chapter_info(m.id, ChapterInfoRetrieved),
    )
    ChapterInfoRetrieved(Ok(chapter_info)) -> {
      let assert option.Some(Ok(progress)) = m.progress
      let updated_progress =
        reader.Progress(
          ..progress,
          series_id: chapter_info.series_id,
          volume_id: chapter_info.volume_id,
        )
      let m =
        Model(
          ..m,
          loading: False,
          progress: option.Some(Ok(updated_progress)),
          chapter_info: option.Some(chapter_info),
        )
      update_title(m)
      #(
        m,
        effect.batch([
          reader.continue_point(chapter_info.series_id, ContinuePointRetrieved),
          reader.prev_chapter(
            chapter_info.series_id,
            chapter_info.volume_id,
            m.id,
            PreviousChapter,
          ),
          reader.next_chapter(
            chapter_info.series_id,
            chapter_info.volume_id,
            m.id,
            NextChapter,
          ),
          series.metadata(chapter_info.series_id, SeriesMetadataRetrieved),
        ]),
      )
    }
    SeriesMetadataRetrieved(Ok(meta)) -> {
      let is_webtoon =
        list.any(meta.tags, fn(t) { t.title |> string.lowercase == "webtoon" })
      case is_webtoon, m.reading_mode {
        True, PageByPage -> #(
          Model(..m, reading_mode: LongStrip),
          effect.none(),
        )
        _, _ -> #(m, effect.none())
      }
    }
    ContinuePointRetrieved(Ok(cont_point)) -> #(
      Model(..m, cont_point: option.Some(cont_point)),
      effect.none(),
    )
    PreviousChapter(Ok(id)) -> #(
      Model(..m, prev_chapter: case id {
        -1 -> option.None
        _ -> option.Some(id)
      }),
      effect.none(),
    )
    NextChapter(Ok(id)) -> #(
      Model(..m, next_chapter: case id {
        -1 -> option.None
        _ -> option.Some(id)
      }),
      effect.none(),
    )
    NavigateRight ->
      case m.prefs.direction {
        LTR -> update(m, Next)
        RTL -> update(m, Previous)
      }
    NavigateLeft ->
      case m.prefs.direction {
        LTR -> update(m, Previous)
        RTL -> update(m, Next)
      }
    Next -> {
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress
      let advanced_progress =
        reader.Progress(
          ..current_progress,
          page_number: current_progress.page_number + 1
            |> int.clamp(min: 0, max: cont_point.pages),
        )
      scroll_reader()
      update_title(m)
      #(
        Model(
          ..m,
          progress: option.Some(Ok(advanced_progress)),
          image_loaded: False,
        ),
        reader.save_progress(advanced_progress, ProgressUpdate),
      )
    }
    Previous -> {
      let assert option.Some(Ok(current_progress)) = m.progress
      case current_progress.page_number - 1 {
        -1 ->
          case m.prev_chapter {
            option.None -> #(m, effect.none())
            option.Some(prev_chapter) -> {
              let assert Ok(prev_uri) =
                uri.parse("/read/" <> int.to_string(prev_chapter))
              #(m, modem.load(prev_uri))
            }
          }
        num -> {
          let assert option.Some(cont_point) = m.cont_point
          let num = case current_progress.page_number == cont_point.pages {
            True -> num - 1
            False -> num
          }
          let advanced_progress =
            reader.Progress(..current_progress, page_number: num)
          scroll_reader()
          update_title(m)
          #(
            Model(
              ..m,
              progress: option.Some(Ok(advanced_progress)),
              image_loaded: False,
            ),
            reader.save_progress(advanced_progress, ProgressUpdate),
          )
        }
      }
    }
    GoToPage(page) -> {
      let assert option.Some(Ok(current_progress)) = m.progress
      let assert option.Some(cont_point) = m.cont_point
      let clamped = int.clamp(page, min: 0, max: cont_point.pages - 1)
      let new_progress =
        reader.Progress(..current_progress, page_number: clamped)
      scroll_reader()
      update_title(m)
      #(
        Model(
          ..m,
          progress: option.Some(Ok(new_progress)),
          image_loaded: False,
          editing_page: False,
        ),
        reader.save_progress(new_progress, ProgressUpdate),
      )
    }
    EditPage -> #(Model(..m, editing_page: True), effect.none())
    ConfirmPageEdit(str) ->
      case int.parse(str) {
        Error(_) -> #(Model(..m, editing_page: False), effect.none())
        Ok(n) -> update(m, GoToPage(n - 1))
      }
    ProgressUpdate(Ok(Nil)) -> {
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress
      case int.compare(current_progress.page_number, cont_point.pages) {
        order.Eq -> {
          let assert Ok(next_uri) = case m.next_chapter {
            option.None ->
              uri.parse("/series/" <> int.to_string(current_progress.series_id))
            option.Some(next_chapter) ->
              uri.parse("/read/" <> int.to_string(next_chapter))
          }
          #(Model(..m, progress: option.None), modem.load(next_uri))
        }
        _ -> #(m, effect.none())
      }
    }
    PageLoaded -> #(
      Model(..m, image_loaded: True, loading: False),
      effect.none(),
    )
    DismissHint -> {
      localstorage.write("reader_hint_seen", "1")
      #(Model(..m, show_hint: False), effect.none())
    }
    ToggleSettings -> #(
      Model(..m, show_settings: !m.show_settings),
      effect.none(),
    )
    ToggleZen -> {
      case m.zen {
        False -> #(
          Model(..m, zen: True),
          effect.from(fn(_) {
            let assert Ok(host) =
              document.get_elements_by_tag_name("reader-page") |> array.get(0)
            let assert Ok(root) = shadow.shadow_root(host)
            let assert Ok(reader_div) =
              shadow.query_selector(root, "#reader-page")
            let _ = plinth_element.request_fullscreen(reader_div)
            Nil
          }),
        )
        True -> #(
          Model(..m, zen: False),
          effect.from(fn(_) {
            let _ = document.exit_fullscreen(window.document(window.self()))
            Nil
          }),
        )
      }
    }
    SyncZen(is_fullscreen) -> #(Model(..m, zen: is_fullscreen), effect.none())
    SetDirection(direction) -> {
      let prefs = ReaderPrefs(..m.prefs, direction:)
      #(Model(..m, prefs:), save_prefs_effect(prefs))
    }
    SetFitMode(fit_mode) -> {
      let prefs = ReaderPrefs(..m.prefs, fit_mode:)
      #(Model(..m, prefs:), save_prefs_effect(prefs))
    }
    SetZoom(zoom) -> {
      let prefs = ReaderPrefs(..m.prefs, zoom:)
      #(Model(..m, prefs:), save_prefs_effect(prefs))
    }
    SetScrollSpeed(scroll_speed) -> {
      let prefs = ReaderPrefs(..m.prefs, scroll_speed:)
      #(Model(..m, prefs:), save_prefs_effect(prefs))
    }
    SetPreloadCount(preload_count) -> {
      let prefs = ReaderPrefs(..m.prefs, preload_count:)
      #(Model(..m, prefs:), save_prefs_effect(prefs))
    }
    SetReadingMode(reading_mode) -> #(Model(..m, reading_mode:), effect.none())
    ScrollUp -> #(m, effect.from(fn(_) { do_scroll_by(-m.prefs.scroll_speed) }))
    ScrollDown -> #(
      m,
      effect.from(fn(_) { do_scroll_by(m.prefs.scroll_speed) }),
    )
    HeaderHover(hovered) -> #(
      Model(..m, header_hovered: hovered),
      effect.none(),
    )
    ScrubberHover(hovered) -> #(
      Model(..m, scrubber_hovered: hovered),
      effect.none(),
    )
    _ -> #(m, effect.none())
  }
}

pub fn view(m: Model) {
  case m.progress {
    option.None | option.Some(Error(_)) -> element.none()
    option.Some(Ok(progress)) -> reader_view(m, progress)
  }
}

fn reader_view(m: Model, progress: reader.Progress) {
  let user = account.get()
  let viewport_w =
    float.truncate(int.to_float(window.inner_width(window.self())) *. 1.25)
  let page_image_url = fn(page: Int) {
    image_url.reader_page(
      progress.chapter_id,
      page,
      user |> account.image_key,
      viewport_w,
    )
  }

  html.div(
    [
      attribute.class(case m.reading_mode {
        PageByPage ->
          "flex flex-col sm:block relative w-full h-screen bg-zinc-950 overflow-hidden"
        LongStrip -> "relative w-full bg-zinc-950"
      }),
      attribute.id("reader-page"),
    ],
    [
      case m.reading_mode {
        PageByPage -> page_view(m, progress, page_image_url)
        LongStrip -> strip_view(m, progress, page_image_url)
      },
      case m.zen {
        True -> element.none()
        False -> reader_top_bar(m, progress)
      },
      // case m.zen {
      //   True -> element.none()
      //   False ->
      //     case m.reading_mode {
      //       LongStrip -> element.none()
      //       PageByPage -> progress_scrubber(m, progress)
      //     }
      // },
      case m.reading_mode {
        LongStrip -> element.none()
        PageByPage -> progress_scrubber(m, progress)
      },
      case m.show_settings {
        True -> settings_panel(m)
        False -> element.none()
      },
      case m.show_hint {
        True -> hint_overlay(m)
        False -> element.none()
      },
    ],
  )
}

fn reader_top_bar(m: Model, progress: reader.Progress) {
  let _ = progress
  html.div(
    [
      case m.reading_mode {
        LongStrip ->
          attribute.class(
            "relative left-0 right-0 z-30 grid grid-cols-3 items-center px-3 py-2 bg-zinc-950/80 backdrop-blur-md text-white",
          )
        PageByPage ->
          attribute.class(
            "sm:absolute sm:top-0 left-0 right-0 z-30 grid grid-cols-3 items-center px-3 py-2 bg-zinc-950/80 backdrop-blur-md text-white transition-opacity duration-200",
          )
      },
      case m.reading_mode {
        LongStrip -> attribute.none()
        PageByPage ->
          case m.header_hovered {
            True -> attribute.none()
            False -> attribute.class("sm:opacity-0")
          }
      },
      event.on("mouseover", decode.success(HeaderHover(True))),
      event.on("mouseleave", decode.success(HeaderHover(False))),
    ],
    [
      html.div([attribute.class("flex items-center gap-1")], [
        case m.chapter_info {
          option.None -> element.none()
          option.Some(info) ->
            button.icon_link(
              "ph ph-arrow-left text-xl",
              "/series/" <> int.to_string(info.series_id),
              [
                button.ghost(),
              ],
            )
        },
        nav_chapter_btn(m.prev_chapter, "ph ph-skip-back"),
        nav_chapter_btn(m.next_chapter, "ph ph-skip-forward"),
      ]),
      html.div(
        [attribute.class("flex flex-col items-center text-center min-w-0")],
        case m.chapter_info {
          option.None -> [
            html.div(
              [
                attribute.class(
                  "bg-zinc-700 animate-pulse h-3.5 w-32 rounded mb-1",
                ),
              ],
              [],
            ),
            html.div(
              [attribute.class("bg-zinc-800 animate-pulse h-3 w-20 rounded")],
              [],
            ),
          ]
          option.Some(info) -> [
            html.span(
              [
                attribute.class(
                  "text-xs font-semibold truncate w-full leading-tight",
                ),
              ],
              [element.text(info.series_name)],
            ),
            html.span(
              [
                attribute.class(
                  "text-xs text-zinc-400 truncate w-full leading-tight",
                ),
              ],
              [element.text(info.subtitle)],
            ),
          ]
        },
      ),
      html.div([attribute.class("flex items-center justify-end gap-1")], [
        button.icon("ph ph-gear text-xl", [
          button.ghost(),
          event.on_click(ToggleSettings),
        ]),
        button.icon("ph ph-eye text-xl", [
          button.ghost(),
          event.on_click(ToggleZen),
        ]),
      ]),
    ],
  )
}

fn nav_chapter_btn(chapter: option.Option(Int), icon: String) {
  case chapter {
    option.None -> button.icon(icon, [button.ghost(), attribute.disabled(True)])
    option.Some(id) ->
      button.icon_link(icon, "/read/" <> int.to_string(id), [
        button.ghost(),
      ])
  }
}

fn page_view(
  m: Model,
  progress: reader.Progress,
  page_image_url: fn(Int) -> String,
) {
  let image_class = case m.prefs.fit_mode {
    FitWidth -> "w-full h-auto max-h-screen object-contain"
    FitHeight -> "h-screen w-auto object-contain"
    Original -> "object-contain"
  }
  let scale =
    "scale(" <> float.to_string(int.to_float(m.prefs.zoom) /. 100.0) <> ")"

  html.div(
    [
      attribute.class(
        "flex-1 relative sm:absolute sm:inset-0 flex justify-center items-center",
      ),
    ],
    [
      html.div(
        [
          event.on_click(Previous),
          attribute.class("absolute top-0 bottom-0 left-0 w-1/2 z-10"),
        ],
        [],
      ),
      html.div(
        [
          event.on_click(Next),
          attribute.class("absolute top-0 bottom-0 right-0 w-1/2 z-10"),
        ],
        [],
      ),
      case m.loading || !m.image_loaded {
        True ->
          html.div(
            [
              attribute.class(
                "absolute inset-0 flex items-center justify-center",
              ),
            ],
            [
              html.i(
                [
                  attribute.class(
                    "ph ph-spinner-ball text-4xl animate-spin text-zinc-400",
                  ),
                ],
                [],
              ),
            ],
          )
        False -> element.none()
      },
      html.img([
        attribute.class(image_class),
        attribute.style("transform", scale),
        attribute.id("reader-img"),
        attribute.src(page_image_url(progress.page_number)),
        event.on("load", { PageLoaded |> decode.success }),
      ]),
      html.div(
        [attribute.class("hidden")],
        list.map(range(1, m.prefs.preload_count), fn(offset) {
          html.img([
            attribute.src(page_image_url(progress.page_number + offset)),
            attribute.class("hidden"),
          ])
        }),
      ),
    ],
  )
}

fn strip_view(
  m: Model,
  progress: reader.Progress,
  page_image_url: fn(Int) -> String,
) {
  let pages = case m.chapter_info {
    option.Some(info) -> info.pages
    option.None -> 0
  }
  let image_class = case m.prefs.fit_mode {
    FitWidth -> "w-full h-auto"
    FitHeight -> "h-screen w-auto mx-auto"
    Original -> "mx-auto"
  }
  let scale =
    "scale(" <> float.to_string(int.to_float(m.prefs.zoom) /. 100.0) <> ")"
  html.div(
    [attribute.class("flex flex-col items-center")],
    list.map(range(0, pages - 1), fn(page) {
      html.img([
        attribute.class(image_class),
        attribute.style("transform", scale),
        attribute.src(page_image_url(page)),
        case page == progress.page_number {
          True -> attribute.id("reader-img")
          False -> attribute.none()
        },
      ])
    }),
  )
}

fn progress_scrubber(m: Model, progress: reader.Progress) {
  let pages = case m.chapter_info {
    option.Some(info) -> info.pages
    option.None -> 1
  }
  let fill_pct =
    int.to_float(progress.page_number + 1) /. int.to_float(pages) *. 100.0

  let page_label = case m.chapter_info {
    option.None ->
      html.div(
        [attribute.class("bg-zinc-700 animate-pulse h-3.5 w-12 rounded")],
        [],
      )
    option.Some(info) ->
      case m.editing_page {
        True ->
          html.input([
            attribute.class(
              "w-12 text-center bg-zinc-800 rounded text-xs text-zinc-200 outline-none border border-zinc-600 focus:border-violet-500 tabular-nums py-0",
            ),
            attribute.type_("number"),
            attribute.attribute("autofocus", ""),
            event.on("keydown", {
              use key <- decode.subfield(["key"], decode.string)
              use value <- decode.subfield(["target", "value"], decode.string)
              case key {
                "Enter" -> decode.success(ConfirmPageEdit(value))
                "Escape" -> decode.success(ConfirmPageEdit(""))
                _ -> decode.failure(EditPage, "not enter/escape")
              }
            }),
            event.on("blur", {
              use v <- decode.subfield(["target", "value"], decode.string)
              decode.success(ConfirmPageEdit(v))
            }),
          ])
        False ->
          button.button(
            int.to_string(progress.page_number + 1)
              <> "/"
              <> int.to_string(info.pages),
            [
              button.ghost(),
              attribute.class("text-xs tabular-nums"),
              event.on_click(EditPage),
            ],
          )
      }
  }

  let scrub_bar = case pages <= 100 {
    False ->
      html.div(
        [
          attribute.class(
            "h-full bg-zinc-800 relative rounded-sm overflow-hidden",
          ),
          event.on("click", {
            use x <- decode.subfield(["offsetX"], decode.float)
            use width <- decode.subfield(
              ["currentTarget", "offsetWidth"],
              decode.float,
            )
            let page =
              float.truncate(x /. width *. int.to_float(pages))
              |> int.clamp(min: 0, max: pages - 1)
            decode.success(GoToPage(page))
          }),
        ],
        [
          html.div(
            [
              attribute.class("h-full bg-violet-500 pointer-events-none"),
              attribute.style("width", float.to_string(fill_pct) <> "%"),
            ],
            [],
          ),
        ],
      )
    True ->
      html.div(
        [attribute.class("flex h-full gap-px")],
        list.map(range(0, pages - 1), fn(i) {
          html.div(
            [
              attribute.class(
                "flex-1 rounded-sm transition-colors cursor-pointer "
                <> case i <= progress.page_number {
                  True -> "bg-violet-500"
                  False -> "bg-zinc-700 hover:bg-violet-400"
                },
              ),
              event.on_click(GoToPage(i)),
            ],
            [],
          )
        }),
      )
  }

  let show = case m.scrubber_hovered {
    True -> attribute.class("max-w-8 max-h-8 opacity-100")
    False -> attribute.class("max-w-0 max-h-0 opacity-0 overflow-hidden")
  }
  let show_label = case m.scrubber_hovered {
    True -> attribute.class("max-w-16 max-h-8 opacity-100")
    False -> attribute.class("max-w-0 max-h-0 opacity-0 overflow-hidden")
  }

  html.div(
    [
      attribute.class(
        "absolute bottom-0 left-0 right-0 z-20 flex flex-col justify-end pb-0 pt-10",
      ),
      event.on("mouseover", decode.success(ScrubberHover(True))),
      event.on("mouseleave", decode.success(ScrubberHover(False))),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex items-center gap-2 px-3 bg-zinc-950/80 backdrop-blur-sm transition-all duration-300 ease-in-out",
          ),
          case m.scrubber_hovered {
            True -> attribute.class("py-1.5")
            False -> attribute.class("py-0")
          },
        ],
        [
          button.icon("ph ph-caret-left", [
            button.ghost(),
            attribute.class("shrink-0 transition-all duration-300 ease-in-out"),
            show,
            event.on_click(Previous),
          ]),
          html.div(
            [
              attribute.class(
                "flex-1 rounded-sm overflow-hidden transition-all duration-300 ease-in-out",
              ),
              case m.scrubber_hovered {
                True -> attribute.class("h-2")
                False -> attribute.class("h-1")
              },
            ],
            [
              scrub_bar,
            ],
          ),
          html.div(
            [
              attribute.class(
                "text-xs text-zinc-400 transition-all duration-300 ease-in-out",
              ),
              show_label,
            ],
            [page_label],
          ),
          button.icon("ph ph-caret-right", [
            button.ghost(),
            attribute.class("shrink-0 transition-all duration-300 ease-in-out"),
            show,
            event.on_click(Next),
          ]),
        ],
      ),
    ],
  )
}

fn settings_panel(m: Model) {
  html.div(
    [
      attribute.class(
        "absolute right-0 top-0 bottom-0 w-72 bg-zinc-900 border-l border-zinc-700 z-40 flex flex-col",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex items-center justify-between p-4 border-b border-zinc-700",
          ),
        ],
        [
          html.h2([attribute.class("font-semibold")], [
            element.text("Reader Settings"),
          ]),
          button.icon("ph ph-x text-xl", [
            button.ghost(),
            event.on_click(ToggleSettings),
          ]),
        ],
      ),
      html.div([attribute.class("flex-1 overflow-y-auto p-4 space-y-6")], [
        settings_section("Reading Direction", [
          btn_group([
            #("LTR", m.prefs.direction == LTR, SetDirection(LTR)),
            #("RTL", m.prefs.direction == RTL, SetDirection(RTL)),
          ]),
        ]),
        settings_section("Reading Mode", [
          btn_group([
            #(
              "Page by Page",
              m.reading_mode == PageByPage,
              SetReadingMode(PageByPage),
            ),
            #(
              "Long Strip",
              m.reading_mode == LongStrip,
              SetReadingMode(LongStrip),
            ),
          ]),
        ]),
        settings_section("Fit Mode", [
          btn_group([
            #("Fit Width", m.prefs.fit_mode == FitWidth, SetFitMode(FitWidth)),
            #(
              "Fit Height",
              m.prefs.fit_mode == FitHeight,
              SetFitMode(FitHeight),
            ),
            #("Original", m.prefs.fit_mode == Original, SetFitMode(Original)),
          ]),
        ]),
        settings_section("Zoom (" <> int.to_string(m.prefs.zoom) <> "%)", [
          html.input([
            attribute.type_("range"),
            attribute.class("w-full accent-violet-500"),
            attribute.attribute("min", "50"),
            attribute.attribute("max", "200"),
            attribute.attribute("step", "25"),
            attribute.value(int.to_string(m.prefs.zoom)),
            event.on_input(fn(v) {
              case int.parse(v) {
                Ok(n) -> SetZoom(n)
                Error(_) -> SetZoom(100)
              }
            }),
          ]),
        ]),
        settings_section(
          "Preload Pages (" <> int.to_string(m.prefs.preload_count) <> ")",
          [
            html.input([
              attribute.type_("range"),
              attribute.class("w-full accent-violet-500"),
              attribute.attribute("min", "0"),
              attribute.attribute("max", "10"),
              attribute.attribute("step", "1"),
              attribute.value(int.to_string(m.prefs.preload_count)),
              event.on_input(fn(v) {
                case int.parse(v) {
                  Ok(n) -> SetPreloadCount(n)
                  Error(_) -> SetPreloadCount(3)
                }
              }),
            ]),
          ],
        ),
        case m.reading_mode {
          PageByPage -> element.none()
          LongStrip ->
            settings_section(
              "Scroll Speed (" <> int.to_string(m.prefs.scroll_speed) <> "px)",
              [
                html.input([
                  attribute.type_("range"),
                  attribute.class("w-full accent-violet-500"),
                  attribute.attribute("min", "100"),
                  attribute.attribute("max", "1000"),
                  attribute.attribute("step", "50"),
                  attribute.value(int.to_string(m.prefs.scroll_speed)),
                  event.on_input(fn(v) {
                    case int.parse(v) {
                      Ok(n) -> SetScrollSpeed(n)
                      Error(_) -> SetScrollSpeed(300)
                    }
                  }),
                ]),
              ],
            )
        },
      ]),
    ],
  )
}

fn settings_section(title: String, children: List(element.Element(Msg))) {
  html.div([attribute.class("space-y-2")], [
    html.p([attribute.class("text-xs text-zinc-400 uppercase tracking-wider")], [
      element.text(title),
    ]),
    ..children
  ])
}

fn btn_group(items: List(#(String, Bool, Msg))) {
  html.div(
    [attribute.class("flex rounded-md overflow-hidden border border-zinc-700")],
    list.map(items, fn(item) {
      let #(label, active, msg) = item
      html.button(
        [
          attribute.type_("button"),
          attribute.class(
            "flex-1 text-sm py-1.5 transition "
            <> case active {
              True -> "bg-violet-600 text-white"
              False -> "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
            },
          ),
          event.on_click(msg),
        ],
        [element.text(label)],
      )
    }),
  )
}

fn hint_overlay(m: Model) {
  let _ = m
  html.div(
    [attribute.class("absolute inset-0 z-50 bg-zinc-950/90 flex flex-col")],
    [
      html.div([attribute.class("flex flex-1")], [
        html.div(
          [
            attribute.class(
              "w-1/2 flex flex-col items-center justify-center gap-3 border-r border-zinc-700 hover:bg-white/5 transition-colors cursor-pointer select-none",
            ),
            event.on_click(DismissHint),
          ],
          [
            html.i(
              [attribute.class("ph ph-arrow-left text-6xl text-white")],
              [],
            ),
            html.span([attribute.class("text-lg font-semibold text-white")], [
              element.text("Previous Page"),
            ]),
            html.span([attribute.class("text-sm text-zinc-400")], [
              element.text("tap / click this half"),
            ]),
          ],
        ),
        html.div(
          [
            attribute.class(
              "w-1/2 flex flex-col items-center justify-center gap-3 hover:bg-white/5 transition-colors cursor-pointer select-none",
            ),
            event.on_click(DismissHint),
          ],
          [
            html.i(
              [attribute.class("ph ph-arrow-right text-6xl text-white")],
              [],
            ),
            html.span([attribute.class("text-lg font-semibold text-white")], [
              element.text("Next Page"),
            ]),
            html.span([attribute.class("text-sm text-zinc-400")], [
              element.text("tap / click this half"),
            ]),
          ],
        ),
      ]),
      html.div(
        [
          attribute.class(
            "border-t border-zinc-800 px-6 py-4 flex items-center justify-between gap-4",
          ),
        ],
        [
          html.div([attribute.class("hidden sm:flex gap-6 text-sm")], [
            hint_keys(["←", "A", "H"], "Previous"),
            hint_keys(["→", "D", "L"], "Next"),
            hint_keys(["Z"], "Zen mode"),
          ]),
          html.p([attribute.class("sm:hidden text-sm text-zinc-400")], [
            element.text("Tap either half to navigate"),
          ]),
          button.button("Got it", [
            button.primary(),
            event.on_click(DismissHint),
          ]),
        ],
      ),
    ],
  )
}

fn hint_keys(keys: List(String), action: String) -> element.Element(Msg) {
  html.div(
    [attribute.class("flex items-center gap-1.5 text-zinc-300")],
    list.append(list.map(keys, hint_key), [
      html.span([attribute.class("text-zinc-500 mx-1")], [element.text("→")]),
      html.span([], [element.text(action)]),
    ]),
  )
}

fn hint_key(label: String) -> element.Element(Msg) {
  html.kbd(
    [
      attribute.class(
        "inline-flex items-center justify-center min-w-[1.6rem] h-6 px-1.5 rounded bg-zinc-700 border border-zinc-600 text-xs font-mono text-zinc-200",
      ),
    ],
    [element.text(label)],
  )
}

fn scroll_reader() {
  let assert Ok(elem) =
    document.get_elements_by_tag_name("reader-page") |> array.get(0)
  let assert Ok(shadow_root) = shadow.shadow_root(elem)

  case shadow_root |> shadow.query_selector("#reader-img") {
    Ok(reader_elem) -> plinth_element.scroll_into_view(reader_elem)
    Error(_) -> Nil
  }
}

fn update_title(m: Model) {
  case m.chapter_info, m.progress {
    option.Some(chapter_info), option.Some(Ok(progress)) ->
      document.set_title(
        chapter_info.series_name
        <> " - "
        <> chapter_info.subtitle
        <> " ("
        <> progress.page_number |> int.to_string
        <> "/"
        <> chapter_info.pages |> int.to_string
        <> ") | Lumiverse",
      )
    _, _ -> Nil
  }
}
