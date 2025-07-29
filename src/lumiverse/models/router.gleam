import lustre_http

// Route Definition
pub type Route {
  Home
  Login
  OIDCCallback
  All
  Series(String)
  NotFound
  Logout
  Reader(chapter_id: Int)
  Upload
  ErrorPage(lustre_http.HttpError)
}

// Update Function with Routing
pub type Msg {
  ChangeRoute(route: Route)
}
