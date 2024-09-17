import gleam/int
import gleam/list
import lustre
import lustre/attribute.{
  type Attribute, attribute, autofocus, checked, class, classes, for, href, id,
  name, on, placeholder, style, type_, value,
} as attr
import lustre/effect.{type Effect, none}
import lustre/element.{type Element, keyed, text}
import lustre/element/html.{
  a, button, div, footer, h1, header, input, label, li, p, section, span, strong,
  ul,
}
import lustre/event.{on_blur, on_click, on_input, on_keydown}
import tardis

pub fn main() {
  let assert Ok(main) = tardis.single("main")

  lustre.application(init, update, view)
  |> tardis.wrap(with: main)
  |> lustre.start("#app", Nil)
  |> tardis.activate(with: main)
}

// MODEL

type Entry {
  Entry(id: Int, description: String, completed: Bool, editing: Bool)
}

type Model {
  Model(entries: List(Entry), field: String, uid: Int, visibility: String)
}

const empty_model = Model(entries: [], field: "", uid: 0, visibility: "All")

fn new_entry(desc: String, id: Int) -> Entry {
  Entry(id: id, description: desc, completed: False, editing: False)
}

fn init(_flags) {
  #(empty_model, none())
}

// UPDATE

pub type Msg {
  NoOp
  UpdateField(String)
  EditingEntry(Int, Bool)
  UpdateEntry(Int, String)
  Add
  Delete(Int)
  DeleteCompleted
  Check(Int, Bool)
  CheckAll(Bool)
  ChangeVisibility(String)
}

fn update(model, msg) {
  case msg {
    NoOp -> #(model, none())
    Add -> {
      #(
        Model(
          ..model,
          uid: model.uid + 1,
          field: "",
          entries: list.append(model.entries, [
            new_entry(model.field, model.uid),
          ]),
        ),
        none(),
      )
    }
    UpdateField(str) -> {
      #(Model(..model, field: str), none())
    }
    EditingEntry(id, editing) -> {
      #(
        Model(
          ..model,
          entries: list.map(model.entries, fn(entry) {
            case entry.id == id {
              True -> Entry(..entry, editing: editing)
              False -> entry
            }
          }),
        ),
        case editing {
          True -> focus_element("todo-" <> int.to_string(id))
          False -> none()
        },
      )
    }
    UpdateEntry(id, desc) -> {
      #(
        Model(
          ..model,
          entries: list.map(model.entries, fn(entry) {
            case entry.id == id {
              True -> Entry(..entry, description: desc)
              False -> entry
            }
          }),
        ),
        none(),
      )
    }
    Delete(id) -> {
      #(
        Model(
          ..model,
          entries: list.filter(model.entries, fn(entry) { entry.id != id }),
        ),
        none(),
      )
    }
    DeleteCompleted -> {
      #(
        Model(
          ..model,
          entries: list.filter(model.entries, fn(entry) { !entry.completed }),
        ),
        none(),
      )
    }
    Check(id, is_completed) -> {
      #(
        Model(
          ..model,
          entries: list.map(model.entries, fn(entry) {
            case entry.id == id {
              True -> Entry(..entry, completed: is_completed)
              False -> entry
            }
          }),
        ),
        none(),
      )
    }
    CheckAll(is_completed) -> {
      #(
        Model(
          ..model,
          entries: list.map(model.entries, fn(entry) {
            Entry(..entry, completed: is_completed)
          }),
        ),
        none(),
      )
    }
    ChangeVisibility(visibility) -> {
      #(Model(..model, visibility: visibility), none())
    }
  }
}

fn view(model: Model) {
  div([class("todomvc-wrapper"), style([#("visibility", "hidden")])], [
    section([class("todoapp")], [
      view_input(model.field),
      view_entries(model.visibility, model.entries),
      view_controls(model.visibility, model.entries),
    ]),
    info_footer(),
  ])
}

fn view_input(task) {
  div([class("input-wrapper")], [
    header([class("header")], [
      h1([], [text("todos")]),
      input([
        class("new-todo"),
        placeholder("What needs to be done?"),
        autofocus(True),
        name("newTodo"),
        value(task),
        on_input(UpdateField),
        on_enter(Add),
      ]),
    ]),
  ])
}

fn on_enter(op) {
  on_keydown(fn(key) {
    case key {
      "Enter" -> op
      _ -> NoOp
    }
  })
}

fn view_entries(visibility: String, entries: List(Entry)) {
  let is_visible = fn(entry: Entry) {
    case visibility {
      "Completed" -> entry.completed
      "Active" -> !entry.completed
      _ -> True
    }
  }
  let all_completed = list.all(entries, fn(entry) { entry.completed })
  let css_visibility = case list.is_empty(entries) {
    True -> "hidden"
    False -> "visible"
  }
  section([class("main"), style([#("visibility", css_visibility)])], [
    input([
      class("toggle-all"),
      type_("checkbox"),
      name("toggle"),
      checked(all_completed),
      on_click(CheckAll(!all_completed)),
    ]),
    label([for("toggle-all")], [text("Mark all as complete")]),
    view_entry_list([class("todo-list")], list.filter(entries, is_visible)),
  ])
}

fn view_entry_list(
  attrs: List(Attribute(Msg)),
  entries: List(Entry),
) -> Element(Msg) {
  keyed(
    fn(children) { ul(attrs, children) },
    list.map(entries, fn(entry: Entry) {
      #(int.to_string(entry.id), view_entry(entry))
    }),
  )
}

fn view_entry(entry: Entry) -> Element(Msg) {
  li([classes([#("completed", entry.completed), #("editing", entry.editing)])], [
    div([class("view")], [
      input([
        class("toggle"),
        type_("checkbox"),
        checked(entry.completed),
        on_click(Check(entry.id, !entry.completed)),
      ]),
      label([on_db_click(EditingEntry(entry.id, True))], [
        text(entry.description),
      ]),
      button([class("destroy"), on_click(Delete(entry.id))], []),
    ]),
    input([
      class("edit"),
      value(entry.description),
      name("title"),
      id("todo-" <> int.to_string(entry.id)),
      on_input(fn(desc) { UpdateEntry(entry.id, desc) }),
      on_blur(EditingEntry(entry.id, False)),
      on_enter(EditingEntry(entry.id, False)),
    ]),
  ])
}

fn view_controls(visibility: String, entries: List(Entry)) {
  let entries_completed =
    list.length(list.filter(entries, fn(entry) { entry.completed }))
  let entries_left = list.length(entries) - entries_completed
  footer([class("footer"), hidden(list.is_empty(entries))], [
    view_controls_count(entries_left),
    view_controls_filteres(visibility),
    view_controls_clear(entries_completed),
  ])
}

fn view_controls_count(entries_left) {
  let item = case entries_left {
    1 -> "item"
    _ -> "items"
  }
  span([class("todo-count")], [
    strong([], [text(int.to_string(entries_left))]),
    text(" "),
    text(item),
    text(" left"),
  ])
}

fn view_controls_filteres(visibility: String) {
  ul([class("filters")], [
    visibility_swap("#/", "All", visibility),
    text(" "),
    visibility_swap("#/active", "Active", visibility),
    text(" "),
    visibility_swap("#/completed", "Completed", visibility),
  ])
}

fn visibility_swap(uri: String, visibility: String, actual_visibility: String) {
  li([on_click(ChangeVisibility(visibility))], [
    a([href(uri), classes([#("selected", visibility == actual_visibility)])], [
      text(visibility),
    ]),
  ])
}

fn view_controls_clear(entries_completed: Int) {
  button(
    [
      class("clear-completed"),
      hidden(entries_completed == 0),
      on_click(DeleteCompleted),
    ],
    [text("Clear completed (" <> int.to_string(entries_completed) <> ")")],
  )
}

fn info_footer() {
  footer([class("info")], [
    p([], [text("Double-click to edit a todo")]),
    p([], [
      text("Written by "),
      a([href("https://github.com")], [text("chendesheng")]),
    ]),
    p([], [
      text("Part of "),
      a([href("https://todomvc.com")], [text("TodoMVC")]),
    ]),
  ])
}

fn hidden(b: Bool) {
  case b {
    True -> attribute("hidden", "hidden")
    False -> attr.none()
  }
}

fn on_db_click(msg: msg) -> Attribute(msg) {
  use _ <- on("dblclick")
  Ok(msg)
}

@external(javascript, "./app.ffi.mjs", "focusElement")
fn do_focus_element(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

fn focus_element(id: String) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    let _ = do_focus_element(id)
    Nil
  })
}
