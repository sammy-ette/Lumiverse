import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/javascript/array
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
import lumiverse/components
import lumiverse/pages/reader/display/long_strip
import lumiverse/pages/reader/display/single
import lumiverse/pages/reader/elements
import lumiverse/pages/reader/hint
import lumiverse/pages/reader/menu
import lumiverse/pages/reader/model
import lumiverse/pages/reader/settings
import lumiverse/pages/reader/utils
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import modem
import plinth/browser/document
import plinth/browser/element as plinth_element
import plinth/browser/shadow
import plinth/browser/window

pub fn register() {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("chapter-id", fn(value) {
        int.parse(value) |> result.map(model.ID)
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

pub fn init(_) {
  let prefs = settings.load_prefs()
  let show_hint = localstorage.read("reader_hint_seen") |> result.is_error
  #(
    model.Model(
      id: 0,
      loading: True,
      progress: option.None,
      cont_point: option.None,
      prev_chapter: option.None,
      next_chapter: option.None,
      chapter_info: option.None,
      pending_chapter_info: option.None,
      image_loaded: False,
      show_hint:,
      show_settings: False,
      show_menu: False,
      settings_section: model.PageLayout,
      reading_mode: model.PageByPage,
      prefs:,
      zen: False,
      editing_page: False,
      scrubber_hovered: False,
      strip_loaded: 10,
    ),
    effect.batch([
      effect.from(fn(dispatch) {
        document.add_event_listener("keydown", fn(raw) {
          case utils.event_key(raw) {
            "ArrowRight" | "d" | "l" -> dispatch(model.NavigateRight)
            "ArrowLeft" | "a" | "h" -> dispatch(model.NavigateLeft)
            "ArrowUp" | "w" -> dispatch(model.ScrollUp)
            "ArrowDown" | "s" -> dispatch(model.ScrollDown)
            "z" -> dispatch(model.ToggleZen)
            _ -> Nil
          }
        })
        Nil
      }),
      effect.from(fn(dispatch) {
        document.add_event_listener("fullscreenchange", fn(_) {
          let doc = window.document(window.self())
          let is_fullscreen = document.fullscreen_element(doc) |> result.is_ok
          dispatch(model.SyncZen(is_fullscreen))
        })
        Nil
      }),
    ]),
  )
}

fn apply_chapter_info(
  m: model.Model,
  chapter_info: reader.ChapterInfo,
) -> #(model.Model, effect.Effect(model.Msg)) {
  let assert option.Some(Ok(progress)) = m.progress
  let updated_progress =
    reader.Progress(
      ..progress,
      series_id: chapter_info.series_id,
      volume_id: chapter_info.volume_id,
    )
  let m =
    model.Model(
      ..m,
      loading: False,
      progress: option.Some(Ok(updated_progress)),
      chapter_info: option.Some(chapter_info),
      pending_chapter_info: option.None,
    )
  utils.update_title(m)
  #(
    m,
    effect.batch([
      reader.continue_point(
        chapter_info.series_id,
        model.ContinuePointRetrieved,
      ),
      reader.prev_chapter(
        chapter_info.series_id,
        chapter_info.volume_id,
        m.id,
        model.PreviousChapter,
      ),
      reader.next_chapter(
        chapter_info.series_id,
        chapter_info.volume_id,
        m.id,
        model.NextChapter,
      ),
      series.metadata(chapter_info.series_id, model.SeriesMetadataRetrieved),
    ]),
  )
}

pub fn update(m: model.Model, msg: model.Msg) {
  case msg {
    model.ID(id) -> #(
      model.Model(
        ..m,
        id:,
        loading: True,
        progress: option.None,
        chapter_info: option.None,
        pending_chapter_info: option.None,
        cont_point: option.None,
        prev_chapter: option.None,
        next_chapter: option.None,
      ),
      effect.batch([
        reader.progress(id, model.ProgressRetrieved),
        reader.chapter_info(id, model.ChapterInfoRetrieved),
      ]),
    )

    model.ProgressRetrieved(Ok(progress)) ->
      case m.pending_chapter_info {
        option.Some(chapter_info) ->
          apply_chapter_info(
            model.Model(
              ..m,
              progress: option.Some(Ok(progress)),
              pending_chapter_info: option.None,
            ),
            chapter_info,
          )
        option.None -> #(
          model.Model(..m, progress: option.Some(Ok(progress))),
          effect.none(),
        )
      }

    model.ChapterInfoRetrieved(Ok(chapter_info)) ->
      case m.progress {
        option.Some(Ok(_)) -> apply_chapter_info(m, chapter_info)
        _ -> #(
          model.Model(..m, pending_chapter_info: option.Some(chapter_info)),
          effect.none(),
        )
      }

    model.NextChapterInfoPrefetched(_) -> #(m, effect.none())
    model.SeriesMetadataRetrieved(Ok(meta)) -> {
      let is_manhwa =
        list.any(meta.tags |> list.append(meta.genres), fn(t) {
          t.title |> string.lowercase == "manhwa"
        })
      case is_manhwa, m.reading_mode {
        True, model.PageByPage -> #(
          model.Model(..m, reading_mode: model.LongStrip),
          effect.none(),
        )
        _, _ -> #(m, effect.none())
      }
    }
    model.ContinuePointRetrieved(Ok(cont_point)) -> #(
      model.Model(..m, cont_point: option.Some(cont_point)),
      effect.none(),
    )
    model.PreviousChapter(Ok(id)) -> #(
      model.Model(..m, prev_chapter: case id {
        -1 -> option.None
        _ -> option.Some(id)
      }),
      effect.none(),
    )
    model.NextChapter(Ok(id)) -> #(
      model.Model(..m, next_chapter: case id {
        -1 -> option.None
        _ -> option.Some(id)
      }),
      effect.none(),
    )
    model.NavigateRight ->
      case m.prefs.direction {
        model.LTR -> update(m, model.Next)
        model.RTL -> update(m, model.Previous)
      }
    model.NavigateLeft ->
      case m.prefs.direction {
        model.LTR -> update(m, model.Previous)
        model.RTL -> update(m, model.Next)
      }
    model.Next -> {
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress
      let advanced_progress =
        reader.Progress(
          ..current_progress,
          page_number: current_progress.page_number + 1
            |> int.clamp(min: 0, max: cont_point.pages),
        )
      utils.scroll_reader()
      // Prefetch next chapter's chapter_info when near the end of the current chapter
      // chapter_info is slow on the server on first request
      let prefetch_eff = case
        m.next_chapter,
        advanced_progress.page_number >= cont_point.pages - 10
      {
        option.Some(next_id), True ->
          reader.chapter_info(next_id, model.NextChapterInfoPrefetched)
        _, _ -> effect.none()
      }
      #(
        model.Model(
          ..m,
          progress: option.Some(Ok(advanced_progress)),
          image_loaded: False,
        ),
        effect.batch([
          reader.save_progress(advanced_progress, model.ProgressUpdate),
          prefetch_eff,
        ]),
      )
    }
    model.Previous -> {
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
          utils.scroll_reader()
          #(
            model.Model(
              ..m,
              progress: option.Some(Ok(advanced_progress)),
              image_loaded: False,
            ),
            reader.save_progress(advanced_progress, model.ProgressUpdate),
          )
        }
      }
    }
    model.GoToPage(page) -> {
      let assert option.Some(Ok(current_progress)) = m.progress
      let assert option.Some(cont_point) = m.cont_point
      let clamped = int.clamp(page, min: 0, max: cont_point.pages - 1)
      let new_progress =
        reader.Progress(..current_progress, page_number: clamped)
      utils.scroll_reader()
      #(
        model.Model(
          ..m,
          progress: option.Some(Ok(new_progress)),
          image_loaded: False,
          editing_page: False,
        ),
        reader.save_progress(new_progress, model.ProgressUpdate),
      )
    }
    model.EditPage -> #(model.Model(..m, editing_page: True), effect.none())
    model.ConfirmPageEdit(str) ->
      case int.parse(str) {
        Error(_) -> #(model.Model(..m, editing_page: False), effect.none())
        Ok(n) -> update(m, model.GoToPage(n - 1))
      }
    model.ProgressUpdate(Ok(Nil)) -> {
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress
      case int.compare(current_progress.page_number, cont_point.pages) {
        order.Eq -> {
          let next_uri = case m.next_chapter {
            option.None ->
              "/series/" <> int.to_string(current_progress.series_id)
            option.Some(next_chapter) -> "/read/" <> int.to_string(next_chapter)
          }
          #(
            model.Model(..m, progress: option.None),
            modem.push(next_uri, option.None, option.None),
          )
        }
        _ -> #(m, effect.none())
      }
    }
    model.PageLoaded -> #(
      model.Model(..m, image_loaded: True, loading: False),
      effect.none(),
    )
    model.DismissHint -> {
      localstorage.write("reader_hint_seen", "1")
      #(model.Model(..m, show_hint: False), effect.none())
    }
    model.ToggleSettings -> #(
      model.Model(
        ..m,
        show_settings: m.show_settings |> bool.negate,
        show_menu: False,
      ),
      effect.none(),
    )
    model.ToggleZen -> {
      case m.zen {
        False -> #(
          model.Model(..m, zen: True),
          effect.from(fn(_) {
            let assert Ok(host) =
              document.get_elements_by_tag_name("reader-page")
              |> array.get(0)
            let assert Ok(root) = shadow.shadow_root(host)
            let assert Ok(reader_div) =
              shadow.query_selector(root, "#reader-content")
            let _ = plinth_element.request_fullscreen(reader_div)
            Nil
          }),
        )
        True -> #(
          model.Model(..m, zen: False),
          effect.from(fn(_) {
            let _ = document.exit_fullscreen(window.document(window.self()))
            Nil
          }),
        )
      }
    }
    model.SyncZen(is_fullscreen) -> #(
      model.Model(..m, zen: is_fullscreen),
      effect.none(),
    )
    model.ScrollUp -> #(
      m,
      effect.from(fn(_) { utils.do_scroll_by(-m.prefs.scroll_speed) }),
    )
    model.ScrollDown -> #(
      m,
      effect.from(fn(_) { utils.do_scroll_by(m.prefs.scroll_speed) }),
    )
    model.ScrubberHover(hovered) -> #(
      model.Model(..m, scrubber_hovered: hovered),
      effect.none(),
    )
    model.LongStripScroll -> {
      let assert Ok(host) =
        document.get_elements_by_tag_name("reader-page")
        |> array.get(0)
      let assert Ok(root) = shadow.shadow_root(host)
      let assert Ok(reader_div) = shadow.query_selector(root, "#reader-content")

      let scroll_height = reader_div |> plinth_element.scroll_height
      let scroll_top = reader_div |> plinth_element.scroll_top
      let client_height = reader_div |> plinth_element.client_height

      echo scroll_top +. { client_height |> int.to_float }
      echo scroll_height

      case
        scroll_top +. { client_height |> int.to_float }
        >=. scroll_height -. 100.0
      {
        True -> #(
          model.Model(..m, strip_loaded: m.strip_loaded + 10),
          effect.none(),
        )
        False -> #(m, effect.none())
      }
    }
    model.ToggleMenu -> menu.update(m, msg)
    _ -> settings.update(m, msg)
  }
}

pub fn view(m: model.Model) {
  utils.update_title(m)

  case m.progress {
    option.None | option.Some(Error(_)) -> element.none()
    option.Some(Ok(progress)) -> reader_view(m, progress)
  }
}

fn reader_view(m: model.Model, progress: reader.Progress) {
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
      attribute.id("reader-page"),
      attribute.class("relative flex flex-col bg-zinc-950 min-h-screen"),
      components.redirect_click(model.Nothing),
    ],
    [
      settings.panel(m),
      menu.panel(m),
      hint.overlay(m),

      // actual reader content
      elements.reader_header(m),
      case m.reading_mode {
        model.PageByPage -> single.view(m, progress, page_image_url)
        model.LongStrip -> long_strip.view(m, progress, page_image_url)
      },
    ],
  )
}
