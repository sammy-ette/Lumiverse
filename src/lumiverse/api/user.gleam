import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import lumiverse/api/account
import lumiverse/api/fetch

pub type AgeRestriction {
  AgeRestriction(age_rating: Int, include_unknowns: Bool)
}

pub type UserLibrary {
  UserLibrary(id: Int, name: String)
}

pub type User {
  User(
    id: Int,
    username: String,
    email: String,
    roles: List(account.Role),
    libraries: List(UserLibrary),
    age_restriction: AgeRestriction,
    identity_provider: Int,
  )
}

fn age_restriction_decoder() -> decode.Decoder(AgeRestriction) {
  use age_rating <- decode.field("ageRating", decode.int)
  use include_unknowns <- decode.field("includeUnknowns", decode.bool)
  decode.success(AgeRestriction(age_rating:, include_unknowns:))
}

fn user_library_decoder() -> decode.Decoder(UserLibrary) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(UserLibrary(id:, name:))
}

fn role_decoder() -> decode.Decoder(account.Role) {
  use variant <- decode.then(decode.string)
  case variant {
    "Admin" -> decode.success(account.Admin)
    "ChangePassword" -> decode.success(account.ChangePassword)
    "Bookmark" -> decode.success(account.Bookmark)
    "Download" -> decode.success(account.Download)
    "ChangeRestriction" -> decode.success(account.ChangeRestriction)
    "ReadOnly" -> decode.success(account.ReadOnly)
    "Login" -> decode.success(account.Login)
    "Promote" -> decode.success(account.Promote)
    r -> decode.success(account.Unknown(r))
  }
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use username <- decode.field("username", decode.string)
  use email <- decode.field(
    "email",
    decode.one_of(decode.string, [decode.success("")]),
  )
  use roles <- decode.field("roles", decode.list(role_decoder()))
  use libraries <- decode.field(
    "libraries",
    decode.list(user_library_decoder()),
  )
  use age_restriction <- decode.field(
    "ageRestriction",
    age_restriction_decoder(),
  )
  use identity_provider <- decode.field("identityProvider", decode.int)
  decode.success(User(
    id:,
    username:,
    email:,
    roles:,
    libraries:,
    age_restriction:,
    identity_provider:,
  ))
}

pub fn all(resp) {
  fetch.get("/api/users?includePending=true", decode.list(user_decoder()), resp)
}

pub fn update(
  user: User,
  roles: List(account.Role),
  library_ids: List(Int),
  resp,
) {
  let body =
    json.object([
      #("userId", json.int(user.id)),
      #("username", json.string(user.username)),
      #("email", json.string(user.email)),
      #("identityProvider", json.int(user.identity_provider)),
      #(
        "roles",
        json.array(roles, fn(r) { json.string(account.role_to_string(r)) }),
      ),
      #("libraries", json.array(library_ids, json.int)),
      #(
        "ageRestriction",
        json.object([
          #("ageRating", json.int(user.age_restriction.age_rating)),
          #("includeUnknowns", json.bool(user.age_restriction.include_unknowns)),
        ]),
      ),
    ])
  fetch.post_empty("/api/Account/update", body, resp)
}

pub fn delete_(id: Int, resp) {
  fetch.delete_empty(
    "/api/users/delete-user?userId=" <> int.to_string(id),
    resp,
  )
}

pub fn library_ids(user: User) -> List(Int) {
  list.map(user.libraries, fn(l) { l.id })
}
