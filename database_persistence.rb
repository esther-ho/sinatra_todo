require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def all_lists
    sql = <<~SQL
    SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
    FROM lists
    LEFT JOIN todos ON lists.id = todos.list_id
    GROUP BY lists.id
    ORDER BY lists.name
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, name)
  end

  def delete_list(id)
    query("DELETE FROM todos WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def find_list(id)
    sql = <<~SQL
    SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
    FROM lists
    LEFT JOIN todos ON lists.id = todos.list_id
    WHERE lists.id = $1
    GROUP BY lists.id
    SQL
    result = query(sql, id)

    tuple = result.first
    list = tuple_to_list_hash(tuple)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, todo_name)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE ROW(list_id, id) = ROW($1, $2)"
    query(sql, list_id, todo_id)
  end

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple["id"].to_i,
        name: tuple["name"],
        completed: (tuple["completed"] == 't') }
    end
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE ROW(list_id, id) = ROW($2, $3)"
    query(sql, new_status, list_id, todo_id)
  end

  def complete_all_todos(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  private

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
    name: tuple["name"],
    todos_count: tuple["todos_count"].to_i,
    todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end
