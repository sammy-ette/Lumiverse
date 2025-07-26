import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import lumiverse/layout
import lumiverse/model
import router

pub fn page(model: model.Model) -> element.Element(layout.Msg) {
  case model.reader_progress {
    option.None -> html.div([], [])
    option.Some(progress) -> {
      let assert option.Some(user) = model.user
      let page_image =
        router.direct(
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
          html.div(
            [attribute.class("border-b-2 border-zinc-900 p-4 space-y-2")],
            [
              case model.viewing_series {
                option.None ->
                  html.div([attribute.class("space-y-2")], [
                    html.div(
                      [attribute.class("bg-zinc-900 animate-pulse h-5 w-60")],
                      [],
                    ),
                    html.div(
                      [attribute.class("bg-zinc-900 animate-pulse h-5 w-36")],
                      [],
                    ),
                  ])
                option.Some(serie) -> {
                  let assert Ok(srs) = serie

                  html.div([], [
                    html.p([], [element.text(srs.name)]),
                    html.p([attribute.class("text-violet-600")], [
                      element.text(srs.localized_name),
                    ]),
                  ])
                }
              },
              html.div(
                [attribute.class("grid grid-cols-3 gap-2 text-center")],
                case
                  model.viewing_series,
                  model.continue_point,
                  model.chapter_info
                {
                  option.Some(_), option.Some(_), option.Some(inf) -> {
                    [
                      html.span(
                        [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
                        [element.text(inf.subtitle)],
                      ),
                      html.span(
                        [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
                        [
                          element.text(
                            "Page "
                            <> int.to_string(progress.page_number + 1)
                            <> " / "
                            <> int.to_string(inf.pages),
                          ),
                        ],
                      ),
                      html.span(
                        [attribute.class("bg-zinc-900 rounded py-0.5 px-1")],
                        [element.text("Menu")],
                      ),
                    ]
                  }
                  _, _, _ -> {
                    [
                      html.div(
                        [attribute.class("bg-zinc-900 animate-pulse h-7")],
                        [],
                      ),
                      html.div(
                        [attribute.class("bg-zinc-900 animate-pulse h-7")],
                        [],
                      ),
                      html.div(
                        [attribute.class("bg-zinc-900 animate-pulse h-7")],
                        [],
                      ),
                    ]
                  }
                },
              ),
            ],
          ),
          html.div(
            [
              event.on_click(layout.ReaderPrevious),
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
              event.on_click(layout.ReaderNext),
              attribute.style("position", "absolute"),
              attribute.style("top", "0"),
              attribute.style("bottom", "0"),
              attribute.style("right", "0"),
              attribute.style("width", "50vw"),
            ],
            [],
          ),
          html.div(
            [attribute.class("flex justify-center items-center h-screen")],
            [
              case model.reader_image_loaded {
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
              html.img(
                list.append(
                  [
                    attribute.class(
                      "h-screen object-contain col-start-1 row-start-1 static",
                    ),
                    attribute.id("reader-img"),
                    attribute.src(page_image),
                    event.on("load", handle_load()),
                  ],
                  case model.reader_image_loaded {
                    False -> [attribute.attribute("hidden", "")]
                    True -> []
                  },
                ),
              ),
            ],
          ),
        ],
      )
    }
  }
}

fn handle_load() {
  decode.new_primitive_decoder("Load", fn(_) {
    // Considering we don't make use of the ID at all.
    // It could also be removed, but eh..
    Ok(layout.ReaderImageLoaded(""))
  })
}
