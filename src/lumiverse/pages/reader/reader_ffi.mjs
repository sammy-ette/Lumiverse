export function eventKey(event) {
  return event.key ?? "";
}

export function scrollBy(amount) {
  window.scrollBy({ top: amount, behavior: "smooth" });
}
