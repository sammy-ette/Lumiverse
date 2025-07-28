import gleam/dynamic/decode
import gleam/fetch/form_data
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import lumiverse/components/button
import lumiverse/models/library
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import router

import lumiverse/layout
import lumiverse/model

type SimpleFormDataValue {
  FormString(String)
  File(BitArray)
}

pub fn page(model: model.Model) -> element.Element(layout.Msg) {
  html.main(
    [
      attribute.class(
        "font-['Poppins'] flex flex-col justify-center items-center space-y-4 px-4 mx-auto flex-1",
      ),
    ],
    [
      html.div(
        [
          attribute.class(case model.upload_result {
            option.None -> "hidden"
            option.Some(Error(_)) -> "border-red-400 text-red-400"
            option.Some(Ok(_)) -> "border-green-400 text-green-400"
          }),
          attribute.class(
            "p-4 mb-4 text-sm rounded-lg border flex gap-2 items-center justify-center",
          ),
        ],
        [
          html.span([attribute.class("icon-info-circle")], []),
          html.span([attribute.class("space-x-2")], case model.upload_result {
            option.None -> []
            option.Some(Error(_)) -> [
              html.span([attribute.class("font-bold")], [
                element.text("Upload failed. "),
              ]),
              element.text("Try again later."),
            ]
            option.Some(Ok(_)) -> [
              html.span([attribute.class("font-bold")], [
                element.text("Upload succeeded! "),
              ]),
              element.text("Series will be added soon."),
            ]
          }),
        ],
      ),
      html.h1([attribute.class("font-bold text-6xl")], [
        element.text("Upload Series"),
      ]),
      html.p([], [
        element.text(
          "Add a new series to Lumiverse. Select the library, upload a ZIP file of CBRs and wait.",
        ),
      ]),
      html.form(
        [
          attribute.class("flex flex-col gap-8"),
          attribute.method("post"),
          attribute.id("upload-form"),
          attribute.action(router.direct_lumify("/api/upload")),
          event.on("submit", {
            use formdata <- decode.subfield(["target", "id"], decode.string)
            formdata |> layout.FormSubmitted |> decode.success
          })
            |> event.prevent_default,
        ],
        [
          html.div([], [
            html.label(
              [attribute.class("block text-white text-md font-semibold mb-2")],
              [element.text("Library")],
            ),
            html.select(
              [
                attribute.name("library"),
                button.md(),
                button.solid(button.Neutral),
                attribute.class("w-full"),
              ],
              list.map(model.libraries, fn(lib: library.Library) {
                html.option([attribute.value(int.to_string(lib.id))], lib.name)
              }),
            ),
          ]),
          html.div([], [
            html.label(
              [attribute.class("block text-white text-md font-semibold mb-2")],
              [element.text("Archive")],
            ),
            html.input([
              attribute.name("archive"),
              attribute.type_("file"),
              button.lg(),
              button.solid(button.Neutral),
            ]),
          ]),
          button.button(
            [
              case model.uploading {
                True -> attribute.disabled(True)
                False -> attribute.none()
              },
              attribute.type_("submit"),
              button.lg(),
              button.solid(button.Primary),
            ],
            [
              case model.uploading {
                True ->
                  html.span(
                    [
                      attribute.disabled(True),
                      attribute.class(
                        "text-neutral-400 icon-circle-o-notch animate-spin",
                      ),
                    ],
                    [],
                  )
                False -> element.text("Upload")
              },
            ],
          ),
        ],
      ),
    ],
  )
}
