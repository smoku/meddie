defmodule Meddie.Repo do
  use Ecto.Repo,
    otp_app: :meddie,
    adapter: Ecto.Adapters.Postgres
end
