import gleam/dynamic
import gleam/json
import gleam/option

import lustre_http as http

pub type Msg {
  LoginSubmitted
  OIDCSubmitted
  OIDCComplete(access_token: String)
  OIDCFailed
  UsernameUpdated(value: String)
  PasswordUpdated(value: String)
  AuthMessage(value: String)
}

pub type LoginDetails {
  LoginDetails(username: String, password: String)
}

pub type LoginRequest {
  LoginRequest(username: String, password: String, api_key: String)
}

pub type Role {
  Admin
  Download
  ChangePassword
  Bookmark
  ChangeRestriction
  Login
  ReadOnly
  Promote
  Unimplemented
}

pub type User {
  User(
    username: String,
    token: String,
    refresh_token: String,
    api_key: String,
    roles: option.Option(List(Role)),
  )
}

pub type Refresh {
  Refresh(token: String, refresh_token: String)
}

pub type Config {
  Config(
    authority: String,
    client_id: String,
    provider_name: String,
    disable_password: Bool,
    auto_login: Bool,
  )
}
