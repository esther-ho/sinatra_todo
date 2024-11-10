require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

configure :development do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  def todos_remaining(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todo_count(list)
    list[:todos].size
  end

  def list_completed?(list)
    todo_count(list) > 0 && todos_remaining(list) == 0
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def sort_lists(lists, &block)
    completed_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }
    (completed_lists + incomplete_lists).each(&block)
  end

  def sort_todos(todos, &block)
    completed_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    (completed_todos + incomplete_todos).each(&block)
  end
end

# Retrieve list using list id. If list is not found, redirect to "/lists"
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the list name is invalid, and return nil otherwise
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "The list name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Render the form to rename an existing list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Rename an existing list
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing list
post "/lists/:list_id/delete" do
  list_id = params[:list_id].to_i
  @storage.delete_list(list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Return an error message if the todo name is invalid, and nil otherwise
def error_for_todo(todo)
  if !(1..100).cover?(todo.size)
    "Todo must be between 1 and 100 characters."
  end
end

# Add a todo item to an existing list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = "A todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from an existing list
post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  is_completed = (params[:completed] == "true")
  @storage.update_todo_status(list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end

# Complete all todos of a single list
post "/lists/:list_id/complete_all" do
  list_id = params[:list_id].to_i
  @storage.complete_all_todos(list_id)

  session[:success] = "All todos have been completed."
  redirect "/lists/#{list_id}"
end
