defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  alias MyApp.Auth
  alias MyApp.Auth.User

  action_fallback(MyAppWeb.FallbackController)

  def index(conn, _params) do
    users = Enum.sort(Auth.list_users())

    render(conn, "index.json", users: users)
  end

  def list(conn, %{"id" => id}) do
    user = Auth.get_user!(id)

    users = orderUsers(user.interests, Auth.list_users())
    render(conn, "index.json", users: List.delete_at(users, 0))
  end

  def orderUsers(base_interests, users) do
    Enum.sort(users, fn a, b ->
      matchesAmount(base_interests, a.interests) > matchesAmount(base_interests, b.interests)
    end)
  end

  defp matchesAmount(base_interests, user_interest) do
    List.myers_difference(base_interests, user_interest)
    |> Enum.reduce(0, &reducingMyersDifference/2)
  end

  defp reducingMyersDifference({:eq, list}, acc) do
    acc + length(list)
  end

  defp reducingMyersDifference(_, acc) do
    acc
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Auth.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Auth.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Auth.get_user!(id)

    with {:ok, %User{} = user} <- Auth.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Auth.get_user!(id)

    with {:ok, %User{}} <- Auth.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  def sign_in(conn, %{"email" => email, "password" => password}) do
    case MyApp.Auth.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> configure_session(renew: true)
        |> put_status(:ok)
        |> put_view(MyAppWeb.UserView)
        |> render("sign_in.json", user: user)

      {:error, message} ->
        conn
        |> delete_session(:current_user_id)
        |> put_status(:unauthorized)
        |> put_view(MyAppWeb.ErrorView)
        |> render("401.json", message: message)
    end
  end

  def sign_up(conn, user_params) do
    case Auth.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> configure_session(renew: true)
        |> put_status(:ok)
        |> put_view(MyAppWeb.UserView)
        |> render("sign_in.json", user: user)

      {:error, message} ->
        conn
        |> delete_session(:current_user_id)
        |> put_status(:unauthorized)
        |> put_view(MyAppWeb.ErrorView)
        |> IO.inspect()
        |> render("401.json", message: message)
    end
  end
end
