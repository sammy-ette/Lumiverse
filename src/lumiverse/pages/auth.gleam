import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import lumiverse/components/button.{button}
import lumiverse/config
import lumiverse/layout
import lumiverse/model
import lumiverse/models/auth

const input_class = "bg-zinc-700 rounded-md p-1 text-zinc-200 focus:ring-0 focus:border-violet-600"

pub fn login(model: model.Model) {
  container([
    html.div(
      [
        attribute.class(
          "rounded-md bg-zinc-900 border-t-[5px] border-violet-600",
        ),
      ],
      [
        html.div([attribute.class("px-9 py-6 flex flex-col space-y-4")], [
          html.h1(
            [attribute.class("font-semibold text-xl text-center text-white")],
            [element.text("Sign in to your account")],
          ),
          html.p([attribute.class("text-center text-violet-600")], [
            element.text(model.auth.auth_message),
          ]),
          case model.oidc_config.disable_password {
            True -> element.none()
            False ->
              html.div([attribute.class("space-y-4")], [
                html.form([attribute.class("space-y-4")], [
                  html.div([], [
                    html.label(
                      [attribute.class("block text-white text-sm mb-2")],
                      [element.text("Username")],
                    ),
                    html.input([
                      attribute.attribute("type", "username"),
                      attribute.class(input_class),
                      event.on_input(fn(a) {
                        layout.AuthPage(auth.UsernameUpdated(a))
                      }),
                    ]),
                  ]),
                  html.div([], [
                    html.label(
                      [attribute.class("block text-white text-sm mb-2")],
                      [element.text("Password")],
                    ),
                    html.input([
                      attribute.attribute("type", "password"),
                      attribute.class(input_class),
                      event.on_input(fn(a) {
                        layout.AuthPage(auth.PasswordUpdated(a))
                      }),
                    ]),
                  ]),
                ]),
                button(
                  [
                    button.solid(button.Primary),
                    button.md(),
                    attribute.class("w-full font-semibold"),
                    event.on_click(layout.AuthPage(auth.LoginSubmitted)),
                  ],
                  [element.text("Sign In")],
                ),
              ])
          },
          case
            model.oidc_config.disable_password
            && model.oidc_config.authority != ""
          {
            True -> element.none()
            False ->
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
          },
          case model.oidc_config.authority == "" {
            True -> element.none()
            False ->
              button(
                [
                  button.solid(button.Neutral),
                  button.md(),
                  attribute.class("w-full font-semibold"),
                  event.on_click(layout.AuthPage(auth.OIDCSubmitted)),
                ],
                case model.doing_oidc {
                  False -> [
                    html.img([
                      attribute.src(config.logo()),
                      attribute.class("h-6"),
                    ]),
                    element.text(
                      "Sign In With " <> model.oidc_config.provider_name,
                    ),
                  ]
                  True -> [
                    html.span(
                      [
                        attribute.class(
                          "text-neutral-400 icon-circle-o-notch animate-spin",
                        ),
                      ],
                      [],
                    ),
                  ]
                },
              )
          },
        ]),
        // html.div(
      //   [
      //     attribute.class(
      //       "rounded-b bg-zinc-800 p-3 flex items-center justify-center",
      //     ),
      //   ],
      //   [
      //     html.p([attribute.class("text-zinc-400 text-base")], [
      //       element.text("New here? "),
      //       html.a(
      //         [
      //           attribute.href("/register"),
      //           attribute.class("text-violet-500 text-base"),
      //         ],
      //         [element.text("Register")],
      //       ),
      //     ]),
      //   ],
      // ),
      ],
    ),
  ])
}

pub fn oidc_callback() {
  container([
    html.div(
      [
        attribute.class(
          "rounded-md bg-zinc-900 border-t-[5px] border-violet-600",
        ),
      ],
      [
        html.div([attribute.class("px-9 py-6 flex flex-col space-y-4")], [
          html.h1(
            [attribute.class("font-semibold text-xl text-center text-white")],
            [element.text("Logging In...")],
          ),
        ]),
      ],
    ),
  ])
}

pub fn logout() -> element.Element(layout.Msg) {
  container([
    html.div(
      [attribute.class("card border-0 border-top border-primary border-4")],
      [
        html.div([attribute.class("auth-content")], [
          html.h1([], [element.text("Signing out...")]),
        ]),
      ],
    ),
  ])
}

fn container(
  contents: List(element.Element(layout.Msg)),
) -> element.Element(layout.Msg) {
  html.main(
    [attribute.class("flex flex-col justify-center items-center h-screen")],
    [
      html.div(
        [attribute.class("flex items-center justify-center space-x-2 mb-8")],
        [
          html.img([attribute.src(config.logo()), attribute.class("h-12")]),
          html.span(
            [
              attribute.class(
                "self-center font-['Poppins'] text-5xl font-bold dark:text-white",
              ),
            ],
            [element.text("Lumiverse")],
          ),
        ],
      ),
      ..contents
    ],
  )
}
