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
}

// Update Function with Routing
pub type Msg {
  ChangeRoute(route: Route)
}
