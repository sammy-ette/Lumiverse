import formal/form
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import lumiverse/api/account
import lumiverse/api/library
import lumiverse/api/series
import lumiverse/api/settings
import lumiverse/elements/button
import lumiverse/elements/input
import lumiverse/elements/series as series_element
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp

type OIDCForm {
  OIDCForm(
    enabled: Bool,
    auto_login: Bool,
    disable_password_auth: Bool,
    provision_accounts: Bool,
    require_verified_email: Bool,
    sync_user_settings: Bool,
    provider_name: String,
    authority: String,
    client_id: String,
    client_secret: String,
    roles_prefix: String,
    roles_claim: String,
    default_roles: List(String),
    default_libraries: List(Int),
    default_age_restriction: Int,
    default_include_unknowns: Bool,
    custom_scopes: String,
  )
}

type Model {
  Model(
    server_settings: option.Option(settings.ServerSettings),
    libraries: List(library.Library),
    form: form.Form(OIDCForm),
  )
}

type Msg {
  SettingsRetrieved(Result(settings.ServerSettings, rsvp.Error))
  LibrariesRetrieved(Result(List(library.Library), rsvp.Error))
  FormSubmitted(Result(OIDCForm, form.Form(OIDCForm)))
  Saved(Result(Nil, rsvp.Error))
}

fn oidc_form() {
  form.new({
    use enabled <- form.field("enabled", form.parse_checkbox)
    use auto_login <- form.field("auto_login", form.parse_checkbox)
    use disable_password_auth <- form.field(
      "disable_password_auth",
      form.parse_checkbox,
    )
    use provision_accounts <- form.field(
      "provision_accounts",
      form.parse_checkbox,
    )
    use require_verified_email <- form.field(
      "require_verified_email",
      form.parse_checkbox,
    )
    use sync_user_settings <- form.field(
      "sync_user_settings",
      form.parse_checkbox,
    )
    use provider_name <- form.field("provider_name", form.parse_string)
    use authority <- form.field("authority", form.parse_string)
    use client_id <- form.field("client_id", form.parse_string)
    use client_secret <- form.field("client_secret", form.parse_string)
    use roles_prefix <- form.field("roles_prefix", form.parse_string)
    use roles_claim <- form.field("roles_claim", form.parse_string)
    use default_roles <- form.field(
      "default_roles",
      form.parse_list(form.parse_string),
    )
    use default_libraries <- form.field(
      "default_libraries",
      form.parse_list(form.parse_int),
    )
    use default_age_restriction <- form.field(
      "default_age_restriction",
      form.parse_int,
    )
    use default_include_unknowns <- form.field(
      "default_include_unknowns",
      form.parse_checkbox,
    )
    use custom_scopes <- form.field("custom_scopes", form.parse_string)
    form.success(OIDCForm(
      enabled:,
      auto_login:,
      disable_password_auth:,
      provision_accounts:,
      require_verified_email:,
      sync_user_settings:,
      provider_name:,
      authority:,
      client_id:,
      client_secret:,
      roles_prefix:,
      roles_claim:,
      default_roles:,
      default_libraries:,
      default_age_restriction:,
      default_include_unknowns:,
      custom_scopes:,
    ))
  })
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-oidc")
}

pub fn element() {
  element.element(
    "settings-oidc",
    [attribute.class("flex-1 flex flex-col")],
    [],
  )
}

fn init(_) {
  #(
    Model(server_settings: option.None, libraries: [], form: oidc_form()),
    effect.batch([
      settings.get(SettingsRetrieved),
      library.all(LibrariesRetrieved),
    ]),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    SettingsRetrieved(Ok(s)) -> #(
      Model(..m, server_settings: option.Some(s)),
      effect.none(),
    )
    SettingsRetrieved(Error(_)) -> #(
      m,
      toast("Failed to load settings", "error"),
    )
    LibrariesRetrieved(Ok(libs)) -> #(
      Model(..m, libraries: libs),
      effect.none(),
    )
    LibrariesRetrieved(Error(_)) -> #(m, effect.none())
    FormSubmitted(Ok(f)) -> {
      let assert option.Some(s) = m.server_settings
      let oidc = s.oidc_config
      let updated_oidc =
        settings.OIDCConfig(
          enabled: f.enabled,
          auto_login: f.auto_login,
          disable_password_auth: f.disable_password_auth,
          provision_accounts: f.provision_accounts,
          require_verified_email: f.require_verified_email,
          sync_user_settings: f.sync_user_settings,
          provider_name: case f.provider_name {
            "" -> oidc.provider_name
            v -> v
          },
          authority: case f.authority {
            "" -> oidc.authority
            v -> v
          },
          client_id: case f.client_id {
            "" -> oidc.client_id
            v -> v
          },
          secret: case f.client_secret {
            "" -> oidc.secret
            v -> v
          },
          roles_prefix: case f.roles_prefix {
            "" -> oidc.roles_prefix
            v -> v
          },
          roles_claim: case f.roles_claim {
            "" -> oidc.roles_claim
            v -> v
          },
          default_roles: f.default_roles,
          default_libraries: f.default_libraries,
          default_age_restriction: f.default_age_restriction,
          default_include_unknowns: f.default_include_unknowns,
          custom_scopes: case
            f.custom_scopes
            |> string.split(",")
            |> list.map(string.trim)
            |> list.filter(fn(s) { s != "" })
          {
            [] -> oidc.custom_scopes
            scopes -> scopes
          },
        )
      let updated_settings =
        settings.ServerSettings(..s, oidc_config: updated_oidc)
      #(m, settings.save(updated_settings, Saved))
    }
    FormSubmitted(Error(f)) -> #(Model(..m, form: f), effect.none())
    Saved(Ok(_)) -> #(
      m,
      effect.batch([
        settings.get(SettingsRetrieved),
        toast("Settings saved", "info"),
      ]),
    )
    Saved(Error(_)) -> #(m, toast("Failed to save settings", "error"))
  }
}

fn view(m: Model) {
  case m.server_settings {
    option.None ->
      html.div([attribute.class("flex items-center justify-center flex-1")], [
        html.p([attribute.class("text-zinc-400")], [element.text("Loading…")]),
      ])
    option.Some(s) -> form_view(m, s)
  }
}

fn form_view(m: Model, s: settings.ServerSettings) {
  let oidc = s.oidc_config
  let submit = fn(fields) {
    oidc_form()
    |> form.add_values(fields)
    |> form.run
    |> FormSubmitted
  }

  html.div([attribute.class("space-y-6 h-full w-full overflow-y-auto pr-2")], [
    html.div([attribute.class("flex justify-between items-center")], [
      html.h1([attribute.class("text-5xl font-bold")], [element.text("OIDC")]),
    ]),
    html.form([attribute.class("space-y-8"), event.on_submit(submit)], [
      section("General", [
        form_toggle("Enabled", "enabled", oidc.enabled),
        input.input_with_name("Provider Name", [
          attribute.placeholder("e.g. Authelia"),
          filled_value(oidc.provider_name),
          attribute.class("w-full max-w-sm"),
        ]),
        form_toggle("Auto Login", "auto_login", oidc.auto_login),
      ]),
      section("Authentication", [
        form_toggle(
          "Disable Password Authentication",
          "disable_password_auth",
          oidc.disable_password_auth,
        ),
        input.input_with_name("Authority", [
          attribute.placeholder("e.g. https://auth.example.com"),
          filled_value(oidc.authority),
          attribute.class("w-full max-w-sm"),
        ]),
        input.input_with_name("Client ID", [
          filled_value(oidc.client_id),
          attribute.class("w-full max-w-sm"),
        ]),
        input.input_with_name("Client Secret", [
          attribute.type_("password"),
          filled_value(oidc.secret),
          attribute.class("w-full max-w-sm"),
        ]),
        input.input_with_name("Custom Scopes", [
          attribute.placeholder("e.g. openid, profile, email"),
          filled_value(string.join(oidc.custom_scopes, ", ")),
          attribute.class("w-full max-w-sm"),
        ]),
      ]),
      section("Provisioning", [
        form_toggle(
          "Auto Create Linked Accounts",
          "provision_accounts",
          oidc.provision_accounts,
        ),
        form_toggle(
          "Require Verified Email",
          "require_verified_email",
          oidc.require_verified_email,
        ),
        form_toggle(
          "Sync User Settings",
          "sync_user_settings",
          oidc.sync_user_settings,
        ),
        html.div([attribute.class("space-y-2")], [
          input.label("Default Roles"),
          html.div(
            [attribute.class("grid grid-cols-2 gap-x-6 gap-y-2 mt-1")],
            list.map(account.all_roles(), fn(role) {
              let val = account.role_to_string(role)
              html.label(
                [
                  attribute.class(
                    "flex items-center gap-2 cursor-pointer select-none",
                  ),
                ],
                [
                  html.input([
                    attribute.type_("checkbox"),
                    attribute.name("default_roles"),
                    attribute.value(val),
                    attribute.checked(list.contains(oidc.default_roles, val)),
                    attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
                  ]),
                  html.span([attribute.class("text-sm text-zinc-300")], [
                    element.text(account.role_to_string(role)),
                  ]),
                ],
              )
            }),
          ),
        ]),
        html.div([attribute.class("space-y-2")], [
          input.label("Default Libraries"),
          case m.libraries {
            [] ->
              html.p([attribute.class("text-sm text-zinc-500")], [
                element.text("No libraries found"),
              ])
            libs ->
              html.div(
                [attribute.class("grid grid-cols-2 gap-x-6 gap-y-2 mt-1")],
                list.map(libs, fn(lib) {
                  let val = int.to_string(lib.id)
                  html.label(
                    [
                      attribute.class(
                        "flex items-center gap-2 cursor-pointer select-none",
                      ),
                    ],
                    [
                      html.input([
                        attribute.type_("checkbox"),
                        attribute.name("default_libraries"),
                        attribute.value(val),
                        attribute.checked(list.contains(
                          oidc.default_libraries,
                          lib.id,
                        )),
                        attribute.class(
                          "accent-violet-500 w-4 h-4 cursor-pointer",
                        ),
                      ]),
                      html.span([attribute.class("text-sm text-zinc-300")], [
                        element.text(lib.name),
                      ]),
                    ],
                  )
                }),
              )
          },
        ]),
      ]),
      section("Age Restriction", [
        html.div([attribute.class("space-y-2")], [
          input.label("Default Age Restriction"),
          html.select(
            [
              attribute.name("default_age_restriction"),
              attribute.class(
                "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none",
              ),
            ],
            list.map(series.all_age_ratings(), fn(rating) {
              let val = int.to_string(series.age_rating_to_int(rating))
              html.option(
                [
                  attribute.value(val),
                  attribute.selected(
                    series.age_rating_to_int(rating)
                    == oidc.default_age_restriction,
                  ),
                ],
                series_element.age_rating_label(rating),
              )
            }),
          ),
        ]),
        form_toggle(
          "Include Items with Unknown Age Rating",
          "default_include_unknowns",
          oidc.default_include_unknowns,
        ),
      ]),
      section("Roles & Claims", [
        input.input_with_name("Roles Prefix", [
          attribute.placeholder("Roles claim prefix"),
          filled_value(oidc.roles_prefix),
          attribute.class("w-full max-w-sm"),
        ]),
        input.input_with_name("Roles Claim", [
          attribute.placeholder("e.g. roles"),
          filled_value(oidc.roles_claim),
          attribute.class("w-full max-w-sm"),
        ]),
      ]),
      html.div([attribute.class("pt-2")], [
        button.button("Save", [
          attribute.type_("submit"),
          button.primary(),
          attribute.class("font-semibold"),
        ]),
      ]),
    ]),
  ])
}

fn section(title: String, children: List(element.Element(Msg))) {
  html.div([attribute.class("space-y-4")], [
    html.h2(
      [
        attribute.class(
          "text-xl font-semibold text-zinc-200 border-b border-zinc-700 pb-2",
        ),
      ],
      [
        element.text(title),
      ],
    ),
    html.div([attribute.class("space-y-4")], children),
  ])
}

fn form_toggle(label: String, name: String, checked: Bool) {
  html.label(
    [attribute.class("flex items-center gap-2 cursor-pointer select-none")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.name(name),
        attribute.checked(checked),
        attribute.class("sr-only peer"),
      ]),
      html.div(
        [
          attribute.class(
            "relative w-9 h-5 rounded-full transition-colors"
            <> " bg-zinc-600 peer-checked:bg-violet-500"
            <> " after:content-[''] after:absolute after:top-0.5 after:left-0.5"
            <> " after:bg-white after:rounded-full after:w-4 after:h-4 after:transition-all"
            <> " peer-checked:after:translate-x-4",
          ),
        ],
        [],
      ),
      html.span([attribute.class("text-sm text-zinc-300")], [
        element.text(label),
      ]),
    ],
  )
}

fn filled_value(v: String) -> attribute.Attribute(a) {
  case v {
    "" -> attribute.none()
    _ -> attribute.value(v)
  }
}

fn toast(message: String, kind: String) {
  event.emit(
    "toast",
    json.object([
      #("message", json.string(message)),
      #("kind", json.string(kind)),
    ]),
  )
}
