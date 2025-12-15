import formal/form
import gleam/bool
import gleam/json
import gleam/list
import gleam/option
import localstorage
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/elements/button
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import rsvp

type Login {
  Login(username: String, password: String)
}

type Model {
  Model(form: form.Form(Login), oidc_config: option.Option(api.OIDC))
}

type Msg {
  OIDCConfig(Result(api.OIDC, rsvp.Error))
  LoginSubmitted(Result(Login, form.Form(Login)))
  LoginResponse(Result(account.Account, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "login-page")
}

pub fn element() {
  element.element(
    "login-page",
    [
      attribute.class(
        "w-screen h-screen flex flex-col justify-center items-center",
      ),
    ],
    [],
  )
}

fn login_form() {
  form.new({
    use username <- form.field(
      "username",
      form.parse_string |> form.check_not_empty,
    )
    use password <- form.field(
      "password",
      form.parse_string
        |> form.check_not_empty
        |> form.check_string_length_more_than(6),
    )

    form.success(Login(username:, password:))
  })
}

fn init(_) {
  #(
    Model(oidc_config: option.None, form: login_form()),
    case localstorage.read("server_url") {
      Error(_) -> effect.none()
      _ -> api.oidc(OIDCConfig)
    },
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    OIDCConfig(Ok(oidc_config)) -> #(
      Model(..m, oidc_config: option.Some(oidc_config)),
      effect.none(),
    )
    OIDCConfig(Error(e)) -> {
      echo e
      #(m, effect.none())
    }
    LoginSubmitted(Ok(login)) -> #(
      m,
      account.login(login.username, login.password, LoginResponse),
    )
    LoginSubmitted(Error(form)) -> #(Model(..m, form:), effect.none())
    LoginResponse(Ok(account)) -> {
      localstorage.write(
        "user",
        json.object([
          #("username", json.string(account.username)),
          #("token", json.string(account.token)),
          #("refresh_token", json.string(account.refresh_token)),
          #("api_key", json.string(account.api_key)),
        ])
          |> json.to_string,
      )
      #(m, modem.push("/", option.None, option.None))
    }
    LoginResponse(Error(e)) -> {
      case echo e {
        rsvp.HttpError(_) -> {
          let form =
            m.form
            |> form.add_error(
              "login_error",
              form.CustomError("Invalid username or password."),
            )
          #(Model(..m, form:), effect.none())
        }
        _ -> #(m, effect.none())
      }
    }
  }
}

fn view(m: Model) {
  let submit = fn(fields) {
    login_form()
    |> form.add_values(fields)
    |> form.run
    |> LoginSubmitted
  }

  container([
    html.h2([attribute.class("font-bold text-2xl text-center")], [
      element.text("Log In"),
    ]),
    html.small(
      [attribute.class("text-red-400 block")],
      list.map(form.field_error_messages(m.form, "login_error"), element.text),
    ),
    case m.oidc_config {
      option.None -> element.none()
      option.Some(oidc) ->
        html.div([attribute.class("space-y-4")], [
          case oidc.disable_password_auth {
            True -> element.none()
            False ->
              html.form(
                [
                  attribute.class("flex flex-col gap-4"),
                  event.on_submit(submit),
                ],
                [
                  html.div([attribute.class("space-y-1")], [
                    html.label(
                      [
                        attribute.for("username"),
                        attribute.class("block text-sm text-zinc-300"),
                      ],
                      [
                        element.text("Username"),
                      ],
                    ),
                    html.input([
                      attribute.class(
                        "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
                      ),
                      attribute.name("username"),
                      attribute.autocomplete("username"),
                    ]),
                    html.small(
                      [attribute.class("text-red-400 block")],
                      list.map(
                        form.field_error_messages(m.form, "username"),
                        element.text,
                      ),
                    ),
                  ]),
                  html.div([attribute.class("space-y-1")], [
                    html.label(
                      [
                        attribute.for("password"),
                        attribute.class("block text-sm text-zinc-300"),
                      ],
                      [
                        element.text("Password"),
                      ],
                    ),
                    html.input([
                      attribute.class(
                        "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
                      ),
                      attribute.name("password"),
                      attribute.type_("password"),
                      attribute.autocomplete("current-password"),
                    ]),
                    html.small(
                      [attribute.class("text-red-400 block")],
                      list.map(
                        form.field_error_messages(m.form, "password"),
                        element.text,
                      ),
                    ),
                  ]),
                  button.button([button.bg(button.Primary)], [
                    element.text("Log In"),
                  ]),
                ],
              )
          },
          case { oidc.enabled && bool.negate(oidc.disable_password_auth) } {
            True ->
              html.div([attribute.class("relative flex items-center")], [
                html.hr([
                  attribute.class("flex-grow border-t border-violet-400"),
                ]),
                html.span([attribute.class("mx-2 text-violet-400")], [
                  element.text("or"),
                ]),
                html.hr([
                  attribute.class("flex-grow border-t border-violet-400"),
                ]),
              ])
            False -> element.none()
          },
          case oidc.enabled {
            False -> element.none()
            True ->
              button.button(
                [button.bg(button.Neutral), attribute.class("w-full")],
                [
                  element.text(oidc.provider_name),
                ],
              )
          },
        ])
    },
  ])
}

fn container(contents: List(element.Element(a))) -> element.Element(a) {
  html.main(
    [
      attribute.class(
        "flex-1 flex flex-col justify-center items-center h-screen",
      ),
    ],
    [
      html.div(
        [attribute.class("flex items-center justify-center space-x-2 mb-8")],
        [
          //   html.img([attribute.src(config.logo()), attribute.class("h-12")]),
          html.span(
            [
              attribute.class(
                "self-center font-['Poppins'] text-3xl md:text-5xl font-bold dark:text-white",
              ),
            ],
            [element.text("Lumiverse")],
          ),
        ],
      ),
      html.div(
        [
          attribute.class(
            "rounded-md bg-zinc-900 border-t-5 border-violet-500 md:px-9 md:py-6 p-4 space-y-4",
          ),
        ],
        contents,
      ),
    ],
  )
}
