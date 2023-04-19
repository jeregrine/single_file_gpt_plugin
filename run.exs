host = if app = System.get_env("FLY_APP_NAME"), do: "#{app}.fly.dev", else: "localhost"

Application.put_env(:phoenix, :json_library, Jason)
Application.put_env(:phoenix_demo, PhoenixDemo.Endpoint,
  url: [host: host],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000"),
  ],
  server: true,
  live_view: [signing_salt: :crypto.strong_rand_bytes(8) |> Base.encode16()],
  secret_key_base: :crypto.strong_rand_bytes(32) |> Base.encode16(),
  pubsub_server: PhoenixDemo.PubSub,
  debug_errors: true,
  adapter: Bandit.PhoenixAdapter
)

Mix.install([
  {:bandit, ">= 0.7.7"},
  {:jason, "~> 1.4"},
  {:phoenix, "~> 1.7.2"},
  {:cors_plug, "~> 3.0"}
])

defmodule PhoenixDemo.SampleController do
  use Phoenix.Controller

  def index(conn, %{"query" => query}) do
    # TODO Hook this up to something good!
    documents = []

    conn
    |> put_view(PhoenixDemo.SampleJSON)
    |> render("index.json", documents: documents)
  end
end

defmodule PhoenixDemo.SampleJSON do
  @doc """
  Renders a list of documents.
  """
  def index(%{documents: documents}) do
    %{data: for(document <- documents, do: data(document))}
  end

  @doc """
  Renders a single document.
  """
  def show(%{document: document}) do
    %{data: data(document)}
  end

  defp data(document) do
    %{
      title: document.title,
      body: document.body
    }
  end
end

defmodule Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PhoenixDemo do
    pipe_through :api

    get "/gpt-search", SampleController, :index
  end
end

defmodule PhoenixDemo.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_demo
  plug CORSPlug,
    origin: ["http://localhost:4000", "https://chat.openai.com"],
    methods: ["GET", "POST"],
    headers: ["*"]

  plug Plug.Static,
    at: "/",
    from: "./",
    gzip: false,
    only: [".well-known", "openapi.yaml"]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()


  plug(Router)
end


# Dry run for copying cached mix install from builder to runner
if System.get_env("EXS_DRY_RUN") == "true" do
  System.halt(0)
else
  {:ok, _} =
    Supervisor.start_link(
      [PhoenixDemo.Endpoint],
      strategy: :one_for_one
    )

  Process.sleep(:infinity)
end
