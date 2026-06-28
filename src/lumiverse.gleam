import gleam/bool
import gleam/dynamic/decode
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import localstorage
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/image_url
import lumiverse/api/library
import lumiverse/api/lumiverse as lumiverse_api
import lumiverse/api/search as search_api
import lumiverse/api/series as series_api
import lumiverse/elements/dropdown
import lumiverse/pages/all
import lumiverse/pages/error
import lumiverse/pages/home
import lumiverse/pages/integrations
import lumiverse/pages/login
import lumiverse/pages/preferences
import lumiverse/pages/reader/page as reader
import lumiverse/pages/search
import lumiverse/pages/series/page as series
import lumiverse/pages/settings/page as settings
import lumiverse/pages/setup
import lumiverse/toasts
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
    connecting: Bool,
    username: option.Option(String),
    toasts: List(toasts.Toast),
    next_toast_id: Int,
    search_query: String,
    search_preview: option.Option(List(search_api.SeriesSearchResult)),
    search_timeout: option.Option(global.TimerID),
    max_age_rating: Int,
    lumiverse_dropdown_open: Bool,
    user_dropdown_open: Bool,
  )
}

pub type Msg {
  ChangeRoute(router.Route)
  PushRoute(String)
  ServerHealth(Result(response.Response(String), rsvp.Error))
  ServerSetupDone(Result(Bool, rsvp.Error))
  OIDCAuthenticated(Result(Bool, rsvp.Error))
  GotOIDCAccount(Result(account.Account, rsvp.Error))
  OIDCLinkCleared(Result(Nil, rsvp.Error))
  ScanAll
  ScanDone(Result(Nil, rsvp.Error))
  ShowToast(String, toasts.ToastKind)
  DismissToast(Int)
  ToggleLumiverseDropdown
  ToggleUserDropdown
  SearchInput(String)
  SearchTimerSet(global.TimerID)
  DoSearchPreview(String)
  SearchSubmit
  GotSearchPreview(Result(List(search_api.SeriesSearchResult), rsvp.Error))
  GotPreferences(Result(Int, rsvp.Error))
  SetAdultContent(Bool)
  ToggleAdultContent
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
  let assert Ok(_) = home.register()
  let assert Ok(_) = all.register()
  let assert Ok(_) = series.register()
  let assert Ok(_) = reader.register()
  let assert Ok(_) = settings.register()
  let assert Ok(_) = preferences.register()
  let assert Ok(_) = integrations.register()
  let assert Ok(_) = search.register()
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

  #(
    Model(
      route:,
      connecting: True,
      username:,
      toasts: [],
      next_toast_id: 0,
      search_query: "",
      search_preview: option.None,
      search_timeout: option.None,
      max_age_rating: 8,
      lumiverse_dropdown_open: False,
      user_dropdown_open: False,
    ),
    effect.batch([
      modem.init(fn(url) { router.uri_to_route(url) |> ChangeRoute }),
      api.health(ServerHealth),
      case username {
        option.Some(_) -> lumiverse_api.get_preferences(GotPreferences)
        option.None -> effect.none()
      },
    ]),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    ToggleUserDropdown -> #(
      Model(..m, user_dropdown_open: m.user_dropdown_open |> bool.negate),
      effect.none(),
    )
    ToggleLumiverseDropdown -> #(
      Model(
        ..m,
        lumiverse_dropdown_open: m.lumiverse_dropdown_open |> bool.negate,
      ),
      effect.none(),
    )
    OIDCLinkCleared(_) -> #(m, effect.none())
    ChangeRoute(route) ->
      case route {
        router.Logout -> {
          let _ = localstorage.remove("user")
          #(
            Model(..m, route: router.Login, username: option.None),
            effect.batch([
              account.clear_oidc_link(OIDCLinkCleared),
              modem.push("/login", option.None, option.None),
            ]),
          )
        }
        _ -> #(Model(..m, route:, search_preview: option.None), effect.none())
      }
    PushRoute(route) -> #(
      Model(..m, user_dropdown_open: False, lumiverse_dropdown_open: False),
      modem.push(route, option.None, option.None),
    )
    ServerHealth(Ok(_)) -> #(
      Model(..m, connecting: False),
      api.setup_done(ServerSetupDone),
    )
    ServerHealth(Error(_)) -> #(
      Model(..m, connecting: False),
      effect.from(fn(dispatch) {
        dispatch(ShowToast("Cannot connect to server", toasts.Err))
      }),
    )
    ServerSetupDone(Ok(done)) -> {
      let eff = case done {
        True -> {
          let has_real_token = case localstorage.read("user") {
            Ok(user) ->
              case json.parse(user, account.account_decoder()) {
                Ok(acc) -> acc.token != ""
                Error(_) -> False
              }
            Error(_) -> False
          }
          case has_real_token, m.route == router.Login {
            True, _ -> effect.none()
            False, True -> effect.none()
            False, False -> api.oidc_authenticated(OIDCAuthenticated)
          }
        }
        False -> modem.push("/setup", option.None, option.None)
      }
      #(m, eff)
    }
    ServerSetupDone(Error(_)) -> #(m, effect.none())
    OIDCAuthenticated(Ok(True)) -> #(m, account.get_account(GotOIDCAccount))
    OIDCAuthenticated(_) -> {
      case m.route == router.Login {
        True -> #(m, effect.none())
        False -> {
          let assert Ok(path) = uri.parse("/login")
          #(m, modem.load(path))
        }
      }
    }
    GotOIDCAccount(Ok(acc)) -> {
      localstorage.write("user", account.account_to_json(acc) |> json.to_string)
      #(Model(..m, username: option.Some(acc.username)), effect.none())
    }
    GotOIDCAccount(Error(_)) -> {
      let assert Ok(path) = uri.parse("/login")
      #(m, modem.load(path))
    }
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
    SearchInput(query) -> {
      let clear_eff = case m.search_timeout {
        option.Some(tid) -> effect.from(fn(_) { global.clear_timeout(tid) })
        option.None -> effect.none()
      }
      let debounce_eff = case string.length(query) > 1 {
        False -> effect.none()
        True ->
          effect.from(fn(dispatch) {
            let tid =
              global.set_timeout(300, fn() { dispatch(DoSearchPreview(query)) })
            dispatch(SearchTimerSet(tid))
          })
      }
      #(
        Model(
          ..m,
          search_query: query,
          search_preview: option.None,
          search_timeout: option.None,
        ),
        effect.batch([clear_eff, debounce_eff]),
      )
    }
    SearchTimerSet(tid) -> #(
      Model(..m, search_timeout: option.Some(tid)),
      effect.none(),
    )
    DoSearchPreview(query) -> #(
      Model(..m, search_timeout: option.None),
      search_api.search(query, GotSearchPreview),
    )
    SearchSubmit -> #(
      m,
      modem.push(
        "/search?q=" <> uri.percent_encode(m.search_query),
        option.None,
        option.None,
      ),
    )
    GotSearchPreview(Ok(results)) -> #(
      Model(..m, search_preview: option.Some(results)),
      effect.none(),
    )
    GotSearchPreview(Error(_)) -> #(
      Model(..m, search_preview: option.None),
      effect.none(),
    )
    GotPreferences(Ok(rating)) -> #(
      Model(..m, max_age_rating: rating),
      effect.none(),
    )
    GotPreferences(Error(_)) -> #(m, effect.none())
    SetAdultContent(enabled) -> {
      let rating =
        case enabled {
          True -> series_api.AdultsOnly
          False -> series_api.Teen
        }
        |> series_api.age_rating_to_int
      #(m, lumiverse_api.set_preferences(rating, GotPreferences))
    }
    ToggleAdultContent -> {
      let new_value = case m.max_age_rating {
        13 -> series_api.Teen
        _ -> series_api.AdultsOnly
      }
      let rating = new_value |> series_api.age_rating_to_int
      #(m, lumiverse_api.set_preferences(rating, GotPreferences))
    }
  }
}

fn view(m: Model) {
  html.div(
    [attribute.class("bg-zinc-950 text-white font-[Poppins,sans-serif]")],
    [
      toasts.toast_overlay(m.toasts, DismissToast),
      case m.connecting {
        True -> view_connecting()
        False -> view_routed(m)
      },
    ],
  )
}

fn view_connecting() {
  html.div(
    [attribute.class("w-screen h-screen flex items-center justify-center")],
    [
      html.i(
        [
          attribute.class(
            "ph ph-[circle-notch] animate-spin text-4xl text-zinc-400",
          ),
        ],
        [],
      ),
    ],
  )
}

fn view_routed(m: Model) {
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
              attribute.class(case route {
                router.All -> "w-full h-dvh flex flex-col"
                _ -> "w-full min-h-screen flex flex-col"
              }),
            ],
            [
              html.div(
                [
                  attribute.class(
                    "pointer-events-none fixed inset-0 z-[200] opacity-[0.1] mix-blend-screen bg-[url('https://assets.astrality.party/website-assets/grain.svg')]",
                  ),
                ],
                [],
              ),
              view_nav(m, route, acc),
              view_main(route, acc),
            ],
          )
        }
      }
  }
}

fn view_nav(m: Model, route: router.Route, acc: account.Account) {
  html.nav(
    [
      attribute.class(
        "z-50 bg-zinc-900/85 backdrop-blur-xl border-b border-zinc-800",
      ),
      case route {
        router.Reader(_) -> attribute.none()
        _ -> attribute.class("sticky top-0 left-0 right-0")
      },
    ],
    [
      html.div([attribute.class("flex items-center justify-between p-3")], [
        view_nav_left(m),
        view_nav_right(m, acc),
      ]),
    ],
  )
}

fn view_nav_left(m: Model) {
  html.div([attribute.class("flex items-center gap-4")], [
    dropdown.dropdown_aligned(
      m.lumiverse_dropdown_open,
      ToggleLumiverseDropdown,
      html.span(
        [
          attribute.class(
            "font-[Poppins,sans-serif] hover:bg-zinc-900 py-1 rounded-xl self-center text-xl font-black flex gap-2 items-end",
          ),
        ],
        [
          html.img([
            attribute.src("/lumiverse.svg"),
            attribute.alt("Lumiverse logo"),
            attribute.class("w-8 h-8 rounded"),
          ]),
          html.span([attribute.class("inline-flex items-center gap-2")], [
            html.span([], [
              element.text("Lumiverse"),
              html.span([attribute.class("text-2xl text-violet-400")], [
                element.text("."),
              ]),
            ]),
            html.i([attribute.class("ph ph-[caret-down]")], []),
          ]),
        ],
      ),
      [
        dropdown.MenuItem(
          "Home",
          option.None,
          PushRoute("/"),
          option.Some("ph ph-[house]"),
          False,
        ),
        dropdown.MenuItem(
          "Browse",
          option.None,
          PushRoute("/all"),
          option.Some("ph ph-[books]"),
          False,
        ),
        dropdown.MenuItem(
          "Search",
          option.None,
          PushRoute("/search"),
          option.Some("ph ph-[magnifying-glass]"),
          False,
        ),
      ],
      dropdown.AlignLeft,
    ),
    html.div([attribute.class("border-r border-zinc-700 w-px h-6")], []),
    view_search(m),
  ])
}

fn view_search(m: Model) {
  html.div([attribute.class("relative hidden md:flex items-center group")], [
    html.input([
      attribute.class(
        "bg-transparent border-b border-transparent py-2 text-white text-sm outline-none focus:border-violet-500 transition-colors",
      ),
      attribute.attribute("placeholder", "Search..."),
      attribute.value(m.search_query),
      event.on_input(SearchInput),
      event.on("keydown", {
        use key <- decode.field("key", decode.string)
        case key {
          "Enter" -> decode.success(SearchSubmit)
          _ -> decode.failure(SearchSubmit, "not enter")
        }
      }),
    ]),
    view_search_preview(m),
  ])
}

fn view_search_preview(m: Model) {
  case m.search_preview {
    option.None -> element.none()
    option.Some([]) -> element.none()
    option.Some(results) -> {
      let user = account.get()
      html.div(
        [
          attribute.class(
            "invisible group-focus-within:visible absolute top-full left-0 mt-1 w-full min-w-72 bg-zinc-900 border border-zinc-700 rounded-lg shadow-xl z-50 overflow-hidden",
          ),
        ],
        list.append(
          list.map(list.take(results, 5), fn(r) {
            let cover_url =
              image_url.series_cover_w(
                r.series_id,
                account.image_key(user),
                100,
              )
            html.a(
              [
                attribute.href("/series/" <> int.to_string(r.series_id)),
                attribute.class(
                  "flex items-center gap-3 px-3 py-2 hover:bg-zinc-800 transition",
                ),
              ],
              [
                html.img([
                  attribute.src(cover_url),
                  attribute.alt(r.name),
                  attribute.class("w-8 h-12 object-cover rounded shrink-0"),
                ]),
                html.span([attribute.class("text-sm text-zinc-200 truncate")], [
                  element.text(r.name),
                ]),
              ],
            )
          }),
          [
            html.a(
              [
                attribute.href(
                  "/search?q=" <> uri.percent_encode(m.search_query),
                ),
                attribute.class(
                  "flex items-center justify-center px-3 py-2 text-sm text-violet-400 hover:bg-zinc-800 transition border-t border-zinc-700",
                ),
              ],
              [element.text("See all results →")],
            ),
          ],
        ),
      )
    }
  }
}

fn view_nav_right(m: Model, acc: account.Account) {
  let is_admin = acc.roles |> list.contains(account.Admin)
  let is_adult =
    m.max_age_rating == series_api.AdultsOnly |> series_api.age_rating_to_int

  html.div([attribute.class("flex items-center gap-3")], [
    dropdown.dropdown(
      m.user_dropdown_open,
      ToggleUserDropdown,
      html.button(
        [
          attribute.class(
            "flex justify-center items-center gap-2 text-sm font-semibold text-zinc-100 hover:text-violet-400 focus:outline-none border-none bg-transparent",
          ),
          attribute.attribute("aria-label", acc.username <> " menu"),
        ],
        [
          html.i([attribute.class("ph ph-[user-circle] text-3xl")], []),
          html.span([attribute.class("hidden sm:inline")], [
            element.text(acc.username),
          ]),
          html.i([attribute.class("ph ph-[caret-down]")], []),
        ],
      ),
      [
        case is_admin {
          False -> dropdown.MenuNone
          True ->
            dropdown.MenuItem(
              "Refresh Libraries",
              option.None,
              ScanAll,
              option.Some("ph ph-[arrow-clockwise]"),
              False,
            )
        },
        case is_admin {
          False -> dropdown.MenuNone
          True ->
            dropdown.MenuItem(
              "Settings",
              option.None,
              PushRoute("/settings"),
              option.Some("ph ph-[gear]"),
              False,
            )
        },
        case is_admin {
          False -> dropdown.MenuNone
          True -> dropdown.MenuDivider
        },
        ..user_dropdown_items(is_adult)
      ],
    ),
  ])
}

fn user_dropdown_items(is_adult: Bool) {
  [
    dropdown.MenuToggle(
      "Adult Content",
      option.None,
      ToggleAdultContent,
      option.Some("ph ph-[prohibit]"),
      is_adult,
    ),
    dropdown.MenuDivider,
    dropdown.MenuItem(
      "Preferences",
      option.None,
      PushRoute("/preferences"),
      option.Some("ph ph-[gear]"),
      False,
    ),
    dropdown.MenuItem(
      "Integrations",
      option.None,
      PushRoute("/integrations"),
      option.Some("ph ph-[plugs]"),
      False,
    ),
    dropdown.MenuItem(
      "Logout",
      option.None,
      ChangeRoute(router.Logout),
      option.Some("ph ph-[sign-out]"),
      False,
    ),
  ]
}

fn view_main(route: router.Route, acc: account.Account) {
  html.main(
    [
      attribute.class(case route {
        router.All -> "flex flex-col flex-1 min-h-0 overflow-hidden"
        _ -> "flex flex-col flex-1"
      }),
    ],
    [
      case route {
        router.Home -> home.element()
        router.All -> all.element([])
        router.Preferences -> preferences.element()
        router.Integrations -> integrations.element()
        router.Settings -> settings.element([toasts.on_toast(ShowToast)])
        router.Series(series_id) ->
          series.element([
            series.id(series_id),
            attribute.property(
              "admin",
              json.bool(acc.roles |> list.contains(account.Admin)),
            ),
          ])
        router.Reader(id) -> reader.element([reader.id(id)])
        router.Search(params) -> search.element([search.query(params.query)])
        _ -> error.page(error.NotFound)
      },
    ],
  )
}
