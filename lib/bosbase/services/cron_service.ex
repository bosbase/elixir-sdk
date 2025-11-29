defmodule Bosbase.CronService do
  @moduledoc "Cron job helpers."

  alias Bosbase.{Client, Utils}

  def get_full_list(client, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/crons", %{query: query, headers: headers})
  end

  def run(client, job_id, body \\ %{}, query \\ %{}, headers \\ %{}) do
    path = "/api/crons/" <> Utils.encode_path_segment(job_id)
    Client.send(client, path, %{method: :post, body: body, query: query, headers: headers})
  end
end
