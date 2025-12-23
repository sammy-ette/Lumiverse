import formal/form
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/uri
import localstorage
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/library
import lumiverse/config
import lumiverse/elements/button
import lumiverse/elements/tag
import lumiverse/pages/home
import lumiverse/pages/login
import lumiverse/pages/reader
import lumiverse/pages/series
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import router
import rsvp

type Model {
  Model(
    route: router.Route,
    server_url: option.Option(String),
    connecting: Bool,
    server_form: form.Form(String),
    server_setup_done: option.Option(Bool),
    roles: List(account.Role),
  )
}

pub type Msg {
  ChangeRoute(router.Route)
  ConnectToServer(Result(String, form.Form(String)))
  ServerHealth(Result(response.Response(String), rsvp.Error))
  ServerSetupDone(Result(Bool, rsvp.Error))
  RolesRetrieved(Result(List(account.Role), rsvp.Error))
  ScanAll
  ScanDone(Result(Nil, rsvp.Error))
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = login.register()
  let assert Ok(_) = home.register()
  let assert Ok(_) = series.register()
  let assert Ok(_) = reader.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

fn init(_) {
  let route =
    modem.initial_uri()
    |> fn(uri) {
      case uri {
        Ok(a) -> router.uri_to_route(a)
        _ -> router.Home
      }
    }

  // let server_url = case localstorage.read("server_url") {
  //   Ok(url) -> url |> option.Some
  //   Error(_) ->
  //     case router.localhost() {
  //       True -> {
  //         localstorage.write("server_url", common.kavita_dev_api)
  //         common.kavita_dev_api |> option.Some
  //       }
  //       False -> option.None
  //     }
  // }
  let server_url = case config.get("SERVER_URL") {
    "" -> localstorage.read("server_url") |> option.from_result
    server_url -> option.Some(server_url)
  }
  let server_form =
    form.new({
      use server_url <- form.field("server_url", form.parse_url)

      form.success(server_url |> uri.to_string)
    })

  #(
    Model(
      route:,
      server_url:,
      connecting: False,
      server_form:,
      server_setup_done: option.None,
      roles: [],
    ),
    effect.batch([
      modem.init(fn(url) { router.uri_to_route(url) |> ChangeRoute }),
      case server_url {
        option.Some(server_url) -> api.health(server_url, ServerHealth)
        option.None -> effect.none()
      },
    ]),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    ChangeRoute(route) -> #(Model(..m, route:), effect.none())
    ConnectToServer(Ok(server_url)) -> #(
      Model(..m, connecting: True, server_url: option.Some(server_url)),
      api.health(server_url, ServerHealth),
    )
    ConnectToServer(Error(server_form)) -> #(
      Model(..m, server_form:),
      effect.none(),
    )
    ServerHealth(Ok(_)) -> {
      let assert option.Some(server_url) = m.server_url
      localstorage.write("server_url", server_url)
      #(
        Model(..m, connecting: False, server_url: option.Some(server_url)),
        api.setup_done(ServerSetupDone),
      )
    }
    ServerHealth(Error(_)) -> #(Model(..m, connecting: True), effect.none())
    ServerSetupDone(Ok(done)) -> {
      let eff = case done {
        True ->
          case localstorage.read("user"), m.route == router.Login {
            Error(_), False -> {
              let assert Ok(path) = uri.parse("/login")
              modem.load(path)
            }
            _, _ -> account.roles(RolesRetrieved)
          }
        False -> modem.push("/setup", option.None, option.None)
      }
      #(m, eff)
    }
    ServerSetupDone(Error(e)) -> {
      echo e
      #(m, effect.none())
    }
    RolesRetrieved(Ok(roles)) -> #(Model(..m, roles:), effect.none())
    RolesRetrieved(Error(_)) -> #(m, effect.none())
    ScanAll -> #(m, library.scan_all(ScanDone))
    ScanDone(_) -> #(m, effect.none())
  }
}

fn view(m: Model) {
  case echo m.server_url, m.connecting {
    option.None, _ | option.Some(_), True -> server_url_view(m)
    option.Some(_), False ->
      case m.route {
        router.Login -> login.element()
        route ->
          html.div(
            [
              attribute.class("w-full flex flex-col"),
            ],
            [
              html.nav(
                [
                  attribute.class(
                    "z-50 bg-zinc-950/85 backdrop-blur-xl border-b border-zinc-600",
                  ),
                  case route {
                    router.Reader(_) -> attribute.none()
                    _ -> attribute.class("sticky top-0 left-0 right-0")
                  },
                ],
                [
                  html.div(
                    [
                      attribute.class(
                        "flex flex-wrap items-center justify-between p-4",
                      ),
                    ],
                    [
                      html.a([attribute.href("/")], [
                        html.span(
                          [
                            attribute.class(
                              "self-center text-2xl font-extrabold flex gap-2",
                            ),
                          ],
                          [
                            element.text("Lumiverse"),
                            tag.simple("Beta", [
                              attribute.class("bg-violet-500"),
                            ]),
                          ],
                        ),
                      ]),
                      html.div(
                        [attribute.class("flex gap-3")],
                        case m.roles |> list.contains(account.Admin) {
                          False -> [element.none()]
                          True -> [
                            button.button([event.on_click(ScanAll)], [
                              html.i(
                                [
                                  attribute.class(
                                    "ph ph-arrow-clockwise text-3xl",
                                  ),
                                ],
                                [],
                              ),
                            ]),
                            button.button([], [
                              html.i(
                                [attribute.class("ph ph-gear-six text-3xl")],
                                [],
                              ),
                            ]),
                          ]
                        },
                      ),
                    ],
                  ),
                ],
              ),
              case route {
                router.Home -> home.element()
                router.Series(series_id) ->
                  series.element([
                    series.id(series_id),
                    attribute.property(
                      "admin",
                      json.bool(m.roles |> list.contains(account.Admin)),
                    ),
                  ])
                router.Reader(id) -> reader.element([reader.id(id)])
                _ -> html.div([], [element.text("Page not found.")])
              },
            ],
          )
      }
  }
}

fn server_url_view(m: Model) {
  let submitted = fn(fields) {
    m.server_form |> form.add_values(fields) |> form.run |> ConnectToServer
  }

  html.div(
    [
      attribute.class("w-screen h-screen flex items-center justify-center"),
    ],
    [
      html.div(
        [
          attribute.class(
            "border-t-5 border-sky-500 rounded-md bg-zinc-900 p-4 space-y-4",
          ),
        ],
        [
          html.form(
            [
              attribute.class("space-y-4"),
              event.on_submit(submitted),
            ],
            [
              html.div([attribute.class("flex flex-col gap-1")], [
                html.label([attribute.class("text-sm text-zinc-300")], [
                  element.text("Kavita URL:"),
                ]),
                html.input([
                  attribute.class(
                    "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-sky-600",
                  ),
                  attribute.name("server_url"),
                ]),
                html.small(
                  [attribute.class("text-zinc-400")],
                  list.map(
                    form.field_error_messages(m.server_form, "server_url"),
                    element.text,
                  ),
                ),
              ]),
              html.button(
                [
                  attribute.class(
                    "relative flex justify-center items-center rounded-md px-4 py-2 font-bold transition outline-none",
                  ),
                  case m.connecting {
                    False -> attribute.class("bg-sky-500")
                    True -> attribute.class("bg-sky-700")
                  },
                ],
                [
                  html.span(
                    [
                      case m.connecting {
                        False -> attribute.none()
                        True -> attribute.class("invisible")
                      },
                    ],
                    [element.text("Connect")],
                  ),
                  html.div(
                    [
                      attribute.class("absolute flex w-fit animate-spin"),
                      case m.connecting {
                        False -> attribute.class("invisible")
                        True -> attribute.none()
                      },
                    ],
                    [
                      html.i([attribute.class("ph ph-circle-notch")], []),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}
