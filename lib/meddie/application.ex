defmodule Meddie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MeddieWeb.Telemetry,
      Meddie.Repo,
      {DNSCluster, query: Application.get_env(:meddie, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Meddie.PubSub},
      {Oban, Application.fetch_env!(:meddie, Oban)},
      # Start to serve requests, typically the last entry
      MeddieWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Meddie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MeddieWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
