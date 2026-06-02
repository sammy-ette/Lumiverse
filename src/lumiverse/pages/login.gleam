import formal/form
import gleam/bool
import gleam/json
import gleam/list
import gleam/option
import gleam/uri
import localstorage
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/elements/button
import lumiverse/elements/input
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import router
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
    OIDCConfig(Ok(oidc_config)) -> {
      let eff = case oidc_config.auto_login {
        True -> {
          let assert Ok(url) = uri.parse(router.direct("/oidc/login"))
          modem.load(url)
        }
        False -> effect.none()
      }
      #(Model(..m, oidc_config: option.Some(oidc_config)), eff)
    }
    OIDCConfig(Error(_)) -> #(m, effect.none())
    LoginSubmitted(Ok(login)) -> #(
      m,
      account.login(login.username, login.password, LoginResponse),
    )
    LoginSubmitted(Error(form)) -> #(Model(..m, form:), effect.none())
    LoginResponse(Ok(user_account)) -> {
      localstorage.write(
        "user",
        account.account_to_json(user_account)
          |> json.to_string,
      )
      #(m, {
        let assert Ok(url) = uri.parse("/")
        modem.load(url)
      })
    }
    LoginResponse(Error(e)) -> {
      case e {
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

  let field_class = "w-full"

  container([
    html.small(
      [attribute.class("text-red-400 block text-center")],
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
                    input.input_with_name("Username", [
                      attribute.class(field_class),
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
                    input.input_with_name("Password", [
                      attribute.class(field_class),
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
                  button.button("Log In", [
                    button.primary(),
                    attribute.class("w-full"),
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
              html.a([attribute.href(router.direct("/oidc/login"))], [
                button.button("Log in with " <> oidc.provider_name, [
                  button.secondary(),
                  attribute.class("w-full py-3 text-base font-semibold"),
                ]),
              ])
          },
        ])
    },
  ])
}

fn container(contents: List(element.Element(a))) -> element.Element(a) {
  html.div([attribute.class("h-screen w-screen flex")], [
    html.main(
      [attribute.class("flex-1 flex flex-col justify-center items-center")],
      [
        html.div([attribute.class("w-full max-w-sm px-8 space-y-6")], [
          html.div([attribute.class("space-y-1")], [
            html.span(
              [
                attribute.class(
                  "font-['Poppins'] text-3xl md:text-4xl font-bold dark:text-white block",
                ),
              ],
              [element.text("Lumiverse")],
            ),
            html.p([attribute.class("text-zinc-400 text-sm")], [
              element.text("Welcome back"),
            ]),
          ]),
          ..contents
        ]),
      ],
    ),
  ])
}
