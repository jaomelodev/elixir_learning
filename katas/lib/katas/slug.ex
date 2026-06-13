defmodule Katas.Slug do
  def from_title(title) when is_binary(title) do
    title
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-z\s]/u, "")
    |> String.replace(~r/\s/, "-")
    |> String.downcase()
  end

  def truncate(slug, max) when is_binary(slug) when is_integer(max) do
    if String.length(slug) <= max do
      slug
    else
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
