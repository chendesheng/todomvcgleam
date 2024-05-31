import { Ok } from "./gleam.mjs";

export function focusElement(id) {
  console.log("focusElement", id);
  setTimeout(() => {
    document.getElementById(id).focus();
  });
  return new Ok();
}
