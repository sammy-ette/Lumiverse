import gleam/list
import lumiverse/pages/settings/auth_keys
import lumiverse/pages/settings/library
import lumiverse/pages/settings/oidc
import lumiverse/pages/settings/users
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

type Model {
  Model(collapsed: List(String), current_subsection: String)
}

type Msg {
  ToggleCollapse(String)
  ChangeSubsection(String)
}

pub fn register() {
  let assert Ok(_) = auth_keys.register()
  let assert Ok(_) = library.register()
  let assert Ok(_) = oidc.register()
  let assert Ok(_) = users.register()

  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-page")
}

pub fn element(attrs: List(attribute.Attribute(a))) {
  element.element(
    "settings-page",
    [attribute.class("flex-1 flex w-full h-full flex-col p-4"), ..attrs],
    [],
  )
}

fn init(_) {
  #(Model(collapsed: [], current_subsection: "Library"), effect.none())
}

fn update(m: Model, msg: Msg) {
  case msg {
    ToggleCollapse(section) -> #(
      Model(..m, collapsed: case m.collapsed |> list.contains(section) {
        False -> [section, ..m.collapsed]
        True ->
          m.collapsed
          |> list.filter(fn(s) { s != section })
      }),
      effect.none(),
    )
    ChangeSubsection(subsection) -> #(
      Model(..m, current_subsection: subsection),
      effect.none(),
    )
  }
}

fn view(m: Model) {
  html.div([attribute.class("flex w-full h-full gap-8")], [
    html.div(
      [attribute.class("bg-zinc-900 rounded-md p-4 w-1/5 h-full flex flex-col")],
      [section(m, "Server")],
    ),
    case m.current_subsection {
      "Library" -> library.element()
      "OIDC" -> oidc.element()
      "Auth Keys" -> auth_keys.element()
      "Users" -> users.element()
      _ -> element.none()
    },
  ])
}

fn section(m: Model, title: String) {
  html.div([attribute.class("flex flex-col")], [
    html.h1(
      [
        event.on_click(ToggleCollapse(title)),
        attribute.class(
          "cursor-pointer font-medium text-2xl flex items-center gap-2",
        ),
      ],
      [
        html.i(
          [
            case m.collapsed |> list.contains(title) {
              True -> attribute.class("ph ph-[caret-right] text-2xl")
              False -> attribute.class("ph ph-[caret-down] text-2xl")
            },
          ],
          [],
        ),
        element.text(title),
      ],
    ),
    case m.collapsed |> list.contains(title) {
      True -> element.none()
      False ->
        html.div(
          [attribute.class("pl-8 flex flex-col gap-2")],
          case title {
            "Server" -> ["Library", "OIDC", "Auth Keys", "Users"]
            _ -> []
          }
            |> list.map(fn(subsection) {
              html.span(
                [
                  attribute.class(
                    "hover:underline cursor-pointer text-violet-400 font-bold",
                  ),
                  event.on_click(ChangeSubsection(subsection)),
                ],
                [element.text(subsection)],
              )
            }),
        )
    },
  ])
}
