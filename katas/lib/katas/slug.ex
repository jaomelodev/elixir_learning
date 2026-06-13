defmodule Katas.Slug do
  @doc """
  Turns `"Hello, World! Ça va?"` into `"hello-world-ca-va"`: lowercase, accents stripped to ASCII where possible, non-alphanumerics collapsed into single dashes, no leading/trailing dash.

  ## Example

      iex> Katas.Slug.from_title("Hello, World! Ça va?")
      "hello-world-ca-va"
  """
  @spec from_title(binary()) :: binary()
  def from_title(title) when is_binary(title) do
    title
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-zA-Z0-9\s-]/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  @doc """
  Cuts at `max` characters without splitting a word and without leaving a trailing dash.

  ## Example

      iex> Katas.Slug.truncate("hello-world-ca-va", 7)
      "hello"
  """
  @spec truncate(binary(), integer()) :: binary()
  def truncate(slug, max) when is_binary(slug) when is_integer(max) do
    case String.length(slug) <= max do
      true ->
        slug

      false ->
        slug
        |> String.slice(0, max)
        |> :binary.matches("-")
        |> List.last()
        |> case do
          {index, _length} -> String.slice(slug, 0, index)
          nil -> String.slice(slug, 0, max)
        end
    end
  end
end
