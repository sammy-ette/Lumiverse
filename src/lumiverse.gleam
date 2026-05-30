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
import lumiverse/toasts
import lumiverse/elements/button
import lumiverse/elements/tag
import lumiverse/pages/error
import lumiverse/pages/home
import lumiverse/pages/login
import lumiverse/pages/reader
import lumiverse/pages/series
import lumiverse/pages/settings/page as settings
import lumiverse/pages/setup
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import plinth/javascript/global
import router
import rsvp

type Model {
  Model(
    route: router.Route,
    server_url: option.Option(String),
    connecting: Bool,
    server_form: form.Form(String),
    server_setup_done: option.Option(Bool),
    username: option.Option(String),
    toasts: List(toasts.Toast),
    next_toast_id: Int,
  )
}

pub type Msg {
  ChangeRoute(router.Route)
  ConnectToServer(Result(String, form.Form(String)))
  ServerHealth(Result(response.Response(String), rsvp.Error))
  ServerSetupDone(Result(Bool, rsvp.Error))
  ScanAll
  ScanDone(Result(Nil, rsvp.Error))
  ShowToast(String, toasts.ToastKind)
  DismissToast(Int)
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = setup.register()
  let assert Ok(_) = login.register()
  case localstorage.read("user") {
    Error(_) -> Nil
    Ok(user) ->
      case json.parse(user, account.account_decoder()) {
        Ok(_) -> Nil
        Error(_) -> {
          let _ = localstorage.remove("user")
          Nil
        }
      }
  }
  case localstorage.read("server_url"), localstorage.read("user") {
    Ok(_server_url), Ok(_user) -> {
      let assert Ok(_) = home.register()
      let assert Ok(_) = series.register()
      let assert Ok(_) = reader.register()
      let assert Ok(_) = settings.register()
      Nil
    }
    _, _ -> Nil
  }
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

  let username = case localstorage.read("user") {
    Ok(user) ->
      case json.parse(user, account.account_decoder()) {
        Ok(acc) -> option.Some(acc.username)
        _ -> option.None
      }
    _ -> option.None
  }

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
      username:,
      toasts: [],
      next_toast_id: 0,
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
    ChangeRoute(route) ->
      case route {
        router.Logout -> {
          let _ = localstorage.remove("user")
          #(
            Model(..m, route: router.Login, username: option.None),
            modem.push("/login", option.None, option.None),
          )
        }
        _ -> #(Model(..m, route:), effect.none())
      }
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
            Error(_), True -> effect.none()
            _, _ -> effect.none()
          }
        False -> modem.push("/setup", option.None, option.None)
      }
      #(m, eff)
    }
    ServerSetupDone(Error(_)) -> #(m, effect.none())
    ScanAll -> #(m, library.scan_all(ScanDone))
    ScanDone(_) -> #(m, effect.none())
    ShowToast(message, kind) -> {
      let id = m.next_toast_id
      #(
        Model(
          ..m,
          toasts: list.append(m.toasts, [toasts.Toast(id:, message:, kind:)]),
          next_toast_id: id + 1,
        ),
        effect.from(fn(dispatch) {
          global.set_timeout(3000, fn() { dispatch(DismissToast(id)) })
          Nil
        }),
      )
    }
    DismissToast(id) -> #(
      Model(..m, toasts: list.filter(m.toasts, fn(t) { t.id != id })),
      effect.none(),
    )
  }
}

fn view(m: Model) {
  html.div(
    [attribute.class("bg-zinc-950 text-white font-[Poppins,sans-serif]")],
    [
      toasts.toast_overlay(m.toasts, DismissToast),
      case m.server_url, m.connecting {
        option.None, _ | option.Some(_), True -> server_url_view(m)
        option.Some(_), False ->
          case m.route {
            router.Login -> login.element()
            router.Setup -> setup.element()
            route ->
              case localstorage.read("user") {
                Error(_) -> element.none()
                Ok(_) -> {
                  let acc = account.get()
                  html.div(
                    [
                      attribute.class("w-full min-h-screen flex flex-col"),
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
                                [attribute.class("flex items-center gap-3")],
                                [
                                  case
                                    acc.roles |> list.contains(account.Admin)
                                  {
                                    False -> element.none()
                                    True ->
                                      button.icon(
                                        "ph ph-arrow-clockwise text-3xl",
                                        [
                                          event.on_click(ScanAll),
                                          button.ghost_inverse(),
                                        ],
                                      )
                                  },
                                  case
                                    acc.roles |> list.contains(account.Admin)
                                  {
                                    False -> element.none()
                                    True ->
                                      button.icon_link(
                                        "ph ph-gear text-3xl",
                                        "/settings",
                                        [button.ghost_inverse()],
                                      )
                                  },
                                  html.div([attribute.class("relative group")], [
                                    html.button(
                                      [
                                        attribute.class(
                                          "flex justify-center items-center gap-2 text-sm font-semibold text-zinc-100 hover:text-violet-400 focus:outline-none border-none bg-transparent",
                                        ),
                                      ],
                                      [
                                        html.i(
                                          [
                                            attribute.class(
                                              "ph ph-user-circle text-3xl",
                                            ),
                                          ],
                                          [],
                                        ),
                                        element.text(acc.username),
                                        html.i(
                                          [attribute.class("ph ph-caret-down")],
                                          [],
                                        ),
                                      ],
                                    ),
                                    html.div(
                                      [
                                        attribute.class(
                                          "invisible absolute right-0 top-full mt-2 min-w-36 rounded-md border border-zinc-700 bg-zinc-900 p-1 transition group-focus-within:visible group-active:visible",
                                        ),
                                      ],
                                      [
                                        html.a(
                                          [
                                            attribute.href("/signout"),
                                            attribute.class(
                                              "block rounded px-3 py-2 text-sm text-zinc-200 hover:bg-zinc-800",
                                            ),
                                          ],
                                          [element.text("Logout")],
                                        ),
                                      ],
                                    ),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      case route {
                        router.Home -> home.element()
                        router.Settings ->
                          settings.element([toasts.on_toast(ShowToast)])
                        router.Series(series_id) ->
                          series.element([
                            series.id(series_id),
                            attribute.property(
                              "admin",
                              json.bool(
                                acc.roles |> list.contains(account.Admin),
                              ),
                            ),
                          ])
                        router.Reader(id) -> reader.element([reader.id(id)])
                        _ -> error.page(error.NotFound)
                      },
                    ],
                  )
                }
              }
          }
      },
    ],
  )
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
