import gleam/list
import lumiverse/api/library
import lumiverse/elements/button
import lumiverse/elements/input
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp

type Model {
  Model(
    libraries: List(library.Library),
    show_creator: Bool,
    paths: List(library.Path),
  )
}

type Msg {
  LibrariesRetrieved(Result(List(library.Library), rsvp.Error))
  ShowCreator(Bool)
  MediaFolderInput(String)
  MediaPaths(Result(List(library.Path), rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-library")
}

pub fn element() {
  element.element(
    "settings-library",
    [
      attribute.class("flex-1 flex flex-col"),
    ],
    [],
  )
}

fn init(_) {
  #(
    Model(libraries: [], show_creator: False, paths: []),
    library.all(LibrariesRetrieved),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    LibrariesRetrieved(Ok(libraries)) -> #(
      Model(..m, libraries:),
      effect.none(),
    )
    ShowCreator(show_creator) -> #(Model(..m, show_creator:), effect.none())
    MediaFolderInput(str) -> {
      echo str
      #(m, effect.none())
    }
    MediaPaths(Ok(paths)) -> #(Model(..m, paths:), effect.none())
    _ -> #(m, effect.none())
  }
}

fn view(m: Model) {
  html.div([attribute.class("space-y-4 h-full w-full")], [
    case m.show_creator {
      True -> creator(m)
      False -> element.none()
    },
    html.div([attribute.class("flex justify-between")], [
      html.h1([attribute.class("text-5xl font-bold")], [
        element.text("Libraries"),
      ]),
      button.button(
        [
          button.lg(),
          button.bg(button.Primary),
          attribute.class("font-bold"),
          event.on_click(ShowCreator(True)),
        ],
        [
          html.i([attribute.class("ph-bold ph-stack-plus text-xl")], []),
          element.text("Add Library"),
        ],
      ),
    ]),
    html.div(
      [],
      list.map(m.libraries, fn(lib) {
        html.div(
          [
            attribute.class(
              "rounded-md w-82 h-48 bg-zinc-900 flex items-center justify-center",
            ),
          ],
          [
            html.span([attribute.class("font-extrabold text-3xl")], [
              element.text(lib.name),
            ]),
          ],
        )
      }),
    ),
  ])
}

fn creator(m: Model) {
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
            "flex flex-col p-4 gap-2 bg-zinc-800 rounded-md h-[80%] w-[60%]",
          ),
        ],
        [
          html.div([attribute.class("flex justify-between items-center")], [
            html.h1([attribute.class("font-bold text-xl")], [
              element.text("Add Library"),
            ]),
            button.button([event.on_click(ShowCreator(False))], [
              html.i([attribute.class("ph ph-x text-2xl")], []),
            ]),
          ]),
          html.form([attribute.class("flex flex-col gap-4")], [
            input.input_with_name("Name", [attribute.class("w-3/4")]),
            html.div([attribute.class("space-y-2")], [
              input.label("Media Folder(s)"),
              html.div([attribute.class("flex gap-2")], [
                html.div([attribute.class("relative flex-1")], [
                  input.input([
                    attribute.class("w-full"),
                    case m.paths |> list.is_empty {
                      False -> attribute.class("rounded-b-none")
                      True -> attribute.none()
                    },
                    event.on_input(MediaFolderInput),
                  ]),
                  case m.paths |> list.is_empty {
                    True -> element.none()
                    False ->
                      html.div(
                        [
                          attribute.class(
                            "rounded-b-md absolute top-full bg-zinc-600 h-42 w-full",
                          ),
                        ],
                        [],
                      )
                  },
                ]),
                button.button([button.bg(button.Primary), button.sm()], [
                  element.text("Add Folder"),
                ]),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  )
}
