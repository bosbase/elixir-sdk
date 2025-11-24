defmodule Bosbase.ClientResponseError do
  @moduledoc """
  Normalized error wrapper returned from the BosBase API.
  """
  defexception [:url, :status, :response, :is_abort, :original_error]

  @type t :: %__MODULE__{
          url: String.t() | nil,
          status: integer() | nil,
          response: map() | nil,
          is_abort: boolean(),
          original_error: term() | nil
        }

  @impl true
  def message(%__MODULE__{status: status, url: url, response: response, is_abort: abort}) do
    "ClientResponseError(status=#{status || "?"}, url=#{url || "?"}, abort=#{abort || false}, response=#{inspect(response)})"
  end
end
