import lumiverse/models/auth as auth_model

import lustre_http as http

pub type Msg {
  Config(Result(auth_model.Config, http.HttpError))
}
