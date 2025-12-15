import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/uri
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/reader
import lustre
import lustre/attribute
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import rsvp

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
    [attribute.class("flex-1 w-screen h-screen"), ..attrs],
    [],
  )
}

pub fn id(id: String) {
  attribute.attribute("chapter-id", id)
}

pub type Model {
  Model(
    progress: option.Option(Result(reader.Progress, rsvp.Error)),
    cont_point: option.Option(reader.ContinuePoint),
    next_chapter: option.Option(Int),
    prev_chapter: option.Option(Int),
  )
}

pub type Msg {
  ID(Int)
  ProgressRetrieved(Result(reader.Progress, rsvp.Error))
  ProgressUpdate(Result(Nil, rsvp.Error))
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
  PreviousChapter(Result(Int, rsvp.Error))
  NextChapter(Result(Int, rsvp.Error))
  Next
  Previous
}

pub fn init(_) {
  #(
    Model(
      progress: option.None,
      cont_point: option.None,
      prev_chapter: option.None,
      next_chapter: option.None,
    ),
    effect.none(),
  )
}

pub fn update(m: Model, msg: Msg) {
  case msg {
    ID(id) -> {
      echo id
      #(m, reader.progress(id, ProgressRetrieved))
    }
    ProgressRetrieved(Ok(progress)) -> #(
      Model(..m, progress: option.Some(Ok(progress))),
      effect.batch([
        reader.prev_chapter(
          progress.series_id,
          progress.volume_id,
          progress.chapter_id,
          PreviousChapter,
        ),
        reader.next_chapter(
          progress.series_id,
          progress.volume_id,
          progress.chapter_id,
          PreviousChapter,
        ),
      ]),
    )
    ContinuePointRetrieved(Ok(cont_point)) -> {
      #(Model(..m, cont_point: option.Some(cont_point)), effect.none())
    }
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
    Next -> {
      echo "next page!"
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress
      let advanced_progress =
        reader.Progress(
          ..current_progress,
          page_number: current_progress.page_number + 1
            |> int.clamp(min: 0, max: cont_point.pages),
        )

      #(
        Model(
          ..m,
          progress: option.Some(Ok(advanced_progress)),
          // reader_image_loaded: False,
        ),
        reader.save_progress(advanced_progress, ProgressUpdate),
      )
    }
    Previous -> #(m, effect.none())
    ProgressUpdate(Ok(Nil)) -> {
      let assert option.Some(cont_point) = m.cont_point
      let assert option.Some(Ok(current_progress)) = m.progress

      case int.compare(current_progress.page_number, cont_point.pages) {
        order.Eq -> {
          let assert Ok(next_uri) = case m.next_chapter {
            option.None ->
              uri.parse("/series/" <> int.to_string(current_progress.series_id))
            option.Some(next_chapter) ->
              uri.parse("/chapter/" <> int.to_string(next_chapter))
          }
          #(
            Model(
              ..m,
              progress: option.None,
              // reader_image_loaded: False,
            ),
            modem.load(next_uri),
          )
        }
        _ -> #(m, effect.none())
      }
    }
    _ -> #(m, effect.none())
  }
}

pub fn view(m: Model) {
  case m.progress {
    option.None | option.Some(Error(_)) -> element.none()
    option.Some(Ok(progress)) -> reader(progress)
  }
}

fn reader(progress: reader.Progress) {
  let user = account.get()
  let page_image =
    api.create_url(
      "/api/reader/image?chapterId="
      <> int.to_string(progress.chapter_id)
      <> "&page="
      <> int.to_string(progress.page_number)
      <> "&apiKey="
      <> user.api_key,
    )

  html.div(
    [
      attribute.class("items-center justify-between"),
      attribute.id("reader-page"),
      attribute.style("position", "relative"),
    ],
    [
      // html.div(
      //   [attribute.class("border-b-2 border-zinc-900 p-4 space-y-2")],
      //   [
      //     case model.viewing_series {
      //       option.None ->
      //         html.div([attribute.class("space-y-2")], [
      //           html.div(
      //             [attribute.class("bg-zinc-900 animate-pulse h-5 w-60")],
      //             [],
      //           ),
      //           html.div(
      //             [attribute.class("bg-zinc-900 animate-pulse h-5 w-36")],
      //             [],
      //           ),
      //         ])
      //       option.Some(serie) -> {
      //         let assert Ok(srs) = serie
      //         html.div([], [
      //           html.p([], [element.text(srs.name)]),
      //           html.p([attribute.class("text-violet-600")], [
      //             element.text(srs.localized_name),
      //           ]),
      //         ])
      //       }
      //     },
      //     html.div(
      //       [attribute.class("grid grid-cols-3 gap-2 text-center")],
      //       case
      //         model.viewing_series,
      //         model.continue_point,
      //         model.chapter_info
      //       {
      //         option.Some(_), option.Some(_), option.Some(inf) -> {
      //           [
      //             html.span(
      //               [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
      //               [element.text(inf.subtitle)],
      //             ),
      //             html.span(
      //               [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
      //               [
      //                 element.text(
      //                   "Page "
      //                   <> int.to_string(
      //                     progress.page_number + 1
      //                     |> int.clamp(min: 0, max: inf.pages),
      //                   )
      //                   <> " / "
      //                   <> int.to_string(inf.pages),
      //                 ),
      //               ],
      //             ),
      //             html.span(
      //               [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
      //               [element.text("Menu")],
      //             ),
      //           ]
      //         }
      //         _, _, _ -> {
      //           [
      //             html.div(
      //               [attribute.class("bg-zinc-900 animate-pulse h-7")],
      //               [],
      //             ),
      //             html.div(
      //               [attribute.class("bg-zinc-900 animate-pulse h-7")],
      //               [],
      //             ),
      //             html.div(
      //               [attribute.class("bg-zinc-900 animate-pulse h-7")],
      //               [],
      //             ),
      //           ]
      //         }
      //       },
      //     ),
      //   ],
      // ),
      html.div(
        [
          // event.on_click(layout.ReaderPrevious),
          attribute.style("position", "absolute"),
          attribute.style("top", "0"),
          attribute.style("bottom", "0"),
          attribute.style("left", "0"),
          attribute.style("width", "50vw"),
        ],
        [],
      ),
      html.div(
        [
          event.on_click(Next),
          attribute.style("position", "absolute"),
          attribute.style("top", "0"),
          attribute.style("bottom", "0"),
          attribute.style("right", "0"),
          attribute.style("width", "50vw"),
        ],
        [],
      ),
      html.div([attribute.class("flex justify-center items-center h-screen")], [
        case True {
          True -> element.none()
          False ->
            html.div(
              [
                attribute.class(
                  "flex h-screen w-1/2 object-contain absolute items-center justify-center",
                ),
              ],
              [
                html.span(
                  [
                    attribute.class(
                      "text-neutral-400 icon-circle-o-notch animate-spin",
                    ),
                  ],
                  [],
                ),
              ],
            )
        },
        html.img(list.append(
          [
            attribute.class(
              "h-screen object-contain col-start-1 row-start-1 static",
            ),
            attribute.id("reader-img"),
            attribute.src(page_image),
            // event.on("load", handle_load()),
          ],
          // case model.reader_image_loaded {
          //   False -> [attribute.attribute("hidden", "")]
          //   True -> []
          // },
          [],
        )),
      ]),
    ],
  )
}
