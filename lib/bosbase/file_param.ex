defmodule Bosbase.FileParam do
  @moduledoc """
  Describes a file part in multipart requests.
  """
  defstruct [:filename, :content, :content_type]

  @type t :: %__MODULE__{
          filename: String.t() | nil,
          content: iodata(),
          content_type: String.t() | nil
        }
end
