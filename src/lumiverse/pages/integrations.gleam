import gleam/uri
import lumiverse/api/lumiverse as lumiverse_api
import lumiverse/api/scrobble
import lumiverse/elements/button
import lumiverse/elements/tag
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import rsvp

type Model {
  Model(anilist_connected: Bool, mal_connected: Bool, reread_enabled: Bool)
}

type Msg {
  StatusLoaded(Result(scrobble.Status, rsvp.Error))
  RereadLoaded(Result(Bool, rsvp.Error))
  ToggleReread(Bool)
  RereadSaved(Result(Bool, rsvp.Error))
  ConnectAniList
  ConnectMAL
  LoginUrlLoaded(Result(String, rsvp.Error))
  DisconnectAniList
  DisconnectMAL
  Disconnected(Result(Nil, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "integrations-page")
}

pub fn element() {
  element.element(
    "integrations-page",
    [attribute.class("flex-1 flex w-full h-full flex-col p-4")],
    [],
  )
}

fn init(_) {
  #(
    Model(anilist_connected: False, mal_connected: False, reread_enabled: False),
    effect.batch([
      scrobble.status(StatusLoaded),
      lumiverse_api.get_reread_enabled(RereadLoaded),
    ]),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    StatusLoaded(Ok(status)) -> #(
      Model(
        ..m,
        anilist_connected: status.anilist_connected,
        mal_connected: status.mal_connected,
      ),
      effect.none(),
    )
    StatusLoaded(Error(_)) -> #(m, effect.none())
    RereadLoaded(Ok(enabled)) -> #(
      Model(..m, reread_enabled: enabled),
      effect.none(),
    )
    RereadLoaded(Error(_)) -> #(m, effect.none())
    ToggleReread(enabled) -> #(
      Model(..m, reread_enabled: enabled),
      lumiverse_api.set_reread_enabled(enabled, RereadSaved),
    )
    RereadSaved(_) -> #(m, effect.none())
    ConnectAniList -> #(m, scrobble.anilist_login(LoginUrlLoaded))
    ConnectMAL -> #(m, scrobble.mal_login(LoginUrlLoaded))
    LoginUrlLoaded(Ok(url)) -> #(m, case uri.parse(url) {
      Ok(parsed) -> modem.load(parsed)
      Error(_) -> effect.none()
    })
    LoginUrlLoaded(Error(_)) -> #(m, effect.none())
    DisconnectAniList -> #(m, scrobble.disconnect_anilist(Disconnected))
    DisconnectMAL -> #(m, scrobble.disconnect_mal(Disconnected))
    Disconnected(_) -> #(m, scrobble.status(StatusLoaded))
  }
}

fn provider_row(
  name: String,
  connected: Bool,
  connect_msg: Msg,
  disconnect_msg: Msg,
) {
  html.div(
    [
      attribute.class(
        "bg-zinc-900 rounded-md p-4 flex items-center justify-between",
      ),
    ],
    [
      html.div([attribute.class("space-y-0.5")], [
        html.span([attribute.class("text-sm font-medium text-zinc-200")], [
          element.text(name),
        ]),
        html.p([attribute.class("text-xs text-zinc-400")], [
          element.text(case connected {
            True -> "Connected"
            False -> "Not connected"
          }),
        ]),
      ]),
      case connected {
        True ->
          button.button("Disconnect", [
            attribute.type_("button"),
            event.on_click(disconnect_msg),
          ])
        False ->
          button.button("Connect", [
            attribute.type_("button"),
            event.on_click(connect_msg),
          ])
      },
    ],
  )
}

fn view(m: Model) {
  html.div([attribute.class("max-w-xl space-y-8")], [
    html.div([attribute.class("space-y-1")], [
      html.div([attribute.class("inline-flex gap-2 items-center")], [
        html.h1([attribute.class("text-3xl font-bold")], [
          element.text("Integrations"),
        ]),
        tag.simple("Beta!", [
          attribute.class(
            "bg-violet-500 normal-case! font-bold! text-[0.9rem]!",
          ),
        ]),
      ]),
      html.p([attribute.class("text-zinc-400 text-sm")], [
        element.text(
          "Connect AniList or MyAnimeList to automatically track your reading progress.",
        ),
      ]),
    ]),
    html.div([attribute.class("space-y-4")], [
      provider_row(
        "AniList",
        m.anilist_connected,
        ConnectAniList,
        DisconnectAniList,
      ),
      provider_row("MyAnimeList", m.mal_connected, ConnectMAL, DisconnectMAL),
    ]),
    html.div([attribute.class("bg-zinc-900 rounded-md p-4")], [
      html.label(
        [
          attribute.class("flex items-center gap-3 cursor-pointer select-none"),
        ],
        [
          html.input([
            attribute.type_("checkbox"),
            attribute.checked(m.reread_enabled),
            attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
            event.on_check(ToggleReread),
          ]),
          html.div([attribute.class("space-y-0.5")], [
            html.span([attribute.class("text-sm font-medium text-zinc-200")], [
              element.text("Track rereads"),
            ]),
            html.p([attribute.class("text-xs text-zinc-400")], [
              element.text(
                "If a series is already marked Completed, finishing a chapter starts a reread instead of being left alone.",
              ),
            ]),
          ]),
        ],
      ),
    ]),
  ])
}
