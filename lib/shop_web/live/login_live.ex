defmodule ShopWeb.LoginLive do
  use ShopWeb, :live_view

  import Phoenix.HTML.Form
  import ShopWeb.ErrorHelpers

  import ShopWeb.Live.Helper,
    only: [
      signing_salt: 0,
      showing_error: 3,
      aria_hidden: 3,
      detail_error: 3,
      inline_error: 3,
      submit_value: 2,
      is_disabled: 1
    ]

  alias Shop.Login

  alias ShopWeb.Router.Helpers, as: Routes

  @impl true
  def render(assigns) do
    ~L"""
    <aside class="opacity-80 hidden bg-no-repeat bg-cover bg-top h-screen w-0 md:fixed lg:fixed lg:w-1/3 lg:bg-scroll lg:block lg:top-0 lg:left-0" role="note" style="background-image: url(<%= Routes.static_path(ShopWeb.Endpoint, "/images/signup.jpg") %>)"></aside>
    <main class="h-screen pt-8 w-auto lg:ml-33pt">
      <div class="flex items-center w-full md:max-w-md md:mx-auto">
        <div class="w-full p-2 m-4">
          <%= form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, class: 'mb-4 md:flex md:flex-wrap md:justify-between', autocomplete: "off", autocorrect: "off", autocapitalize: "off", spellcheck: "false"], fn f -> %>
            <fieldset class="flex flex-col md:w-full" <%= is_disabled(@changeset) %>>
              <div class="text-center mb-5 pb-5"><div class="logo m-auto font-medium"></div></div>
              <div class="text-center mb-4 pt-5 text-xl text-shop-blackr"><h2>Welcome to money without borders.</h2></div>
              <div class="text-center mb-4 pb-5 text-sm">
                <span>Not yet a member? <a class="text-shop-link-blue underline" href="/signup">Sign Up</a></span>
              </div>
              <div class="flex flex-col md:w-full">
                <div class="flex flex-col <%= showing_error(f, @changeset, :email) %> md:w-full fx relative">
                  <%= email_input f, :email, [class: "#{inline_error(f, @changeset, :email)} focus:border focus:border-b-0 rounded border text-grey-darkest", placeholder: "Enter your email address", aria_describedby: "form_email_detail", aria_required: "true", phx_blur: :blur_email] %>
                  <label class="text-gray-500" for="form_email">Email Address</label>
                </div>
                <div aria-live="polite" aria-hidden="<%= aria_hidden(f, @changeset, :email) %>" id="form_email_detail" class="<%= detail_error(f, @changeset, :email) %> detail bg-shop-info pt-2 pb-2 pl-5 pr-4 rounded rounded-t-none relative block border-t-0 border">
                  <span aria-hidden="<%= aria_hidden(f, @changeset, :email) %>" class="text-left text-sm text-shop-black">Email Address Required</span>
                </div>
              </div>
              <div class="flex flex-col md:w-full">
                <div class="flex flex-col <%= showing_error(f, @changeset, :password) %> md:w-full fx relative">
                  <%= password_input f, :password, [value: input_value(f, :password), class: "#{inline_error(f, @changeset, :password)} focus:border focus:border-b-0 rounded border text-grey-darkest", placeholder: "Create a password", aria_describedby: "form_password_detail", aria_required: "true", phx_blur: :blur_password] %>
                  <label class="text-gray-500" for="form_password">Password</label>
                </div>
                <div aria-live="polite" aria-hidden="<%= aria_hidden(f, @changeset, :password) %>" id="form_password_detail" class="<%= detail_error(f, @changeset, :password) %> detail bg-shop-info pt-2 pb-2 pl-5 pr-4 rounded rounded-t-none relative block border-t-0 border">
                  <span aria-hidden="<%= aria_hidden(f, @changeset, :password) %>" class="text-left text-sm text-shop-black"><%= error_tag f, :password %></span>
                </div>
              </div>

              <%= hidden_input f, :email_touched %>
              <%= hidden_input f, :password_touched %>
              <%= hidden_input f, :form_submitted %>
              <%= hidden_input f, :form_disabled %>

              <%= submit submit_value(@changeset, "Login"), [class: "w-full text-white bg-shop-green uppercase font-bold text-lg p-2 rounded"] %>
            </fieldset>
          <% end %>
        </div>
      </div>
    </main>
    """
  end

  @impl true
  def mount(_params, %{"session_uuid" => key}, socket) do
    changeset =
      Login.Form.changeset(%Login.Form{}, %{})
      |> Map.put(:action, :insert)

    {:ok, assign(socket, key: key, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    if Map.get(params, "form_disabled", nil) != "true" do
      changeset =
        Login.Form.changeset(%Login.Form{}, params)
        |> Ecto.Changeset.put_change(:form_submitted, true)
        |> Ecto.Changeset.put_change(:form_disabled, true)
        |> Map.put(:action, :insert)

      send(self(), {:disable_form, changeset})

      {:noreply, assign(socket, changeset: changeset)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    changeset = Login.Form.changeset(%Login.Form{}, params) |> Map.put(:action, :insert)
    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("blur_email", _value, socket) do
    blur_event("email", socket)
  end

  @impl true
  def handle_event("blur_password", _value, socket) do
    blur_event("password", socket)
  end

  def blur_event(field, %{assigns: %{:changeset => changeset}} = socket) do
    changeset =
      changeset
      |> Ecto.Changeset.put_change(:"#{field}_touched", true)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_info({:disable_form, changeset}, %{assigns: %{:key => key}} = socket) do
    case Login.Form.get_user_by_email(changeset) do
      %Shop.User{id: user_id} ->
        insert_session_token(key, user_id)

        path = Routes.shop_path(socket, :index)
        redirect = socket |> redirect(to: path)

        {:noreply, redirect}

      changeset ->
        changeset =
          changeset
          |> Ecto.Changeset.put_change(:form_disabled, false)

        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def insert_session_token(key, user_id) do
    salt = signing_salt()
    token = Phoenix.Token.sign(ShopWeb.Endpoint, salt, user_id)
    :ets.insert(:shop_auth_table, {:"#{key}", token})
  end
end
