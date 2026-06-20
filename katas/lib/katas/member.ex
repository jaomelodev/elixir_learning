defmodule Katas.Member do
  alias Katas.Member
  @enforce_keys [:name, :email]
  defstruct [:name, :email, :age, joined_on: Date.utc_today()]

  @type validation_result(value) :: {:ok, value} | {:error, String.t()}

  @spec new(%{optional(String.t()) => String.t() | nil}) ::
          {:ok, %Member{}} | {:error, %{atom() => String.t()}}
  @doc """
  `Member.new(map_with_string_keys)` returns `{:ok, %Member{}}` or `{:error, errors}`
  where `errors` is a map like `%{age: "must be a positive integer", email: "is invalid"}`.

  Accumulates *all* errors, not just the first.

  ## Type checker note (Elixir 1.20)

  Calling `new/1` with a wrong type is caught only at the `is_map/1` boundary:
  `new(:not_a_map)` is flagged by the set-theoretic checker because the spec input
  is a map. What it *cannot* catch: a map whose string values are wrong domain data
  (`%{"age" => "abc"}`) — those are valid `String.t()` to the type system, so the
  type checker stays silent and our runtime validators do the work. That gap is
  exactly why hand-rolled validation (and later Ecto changesets) exists.
  """
  def new(map) when is_map(map) do
    [
      {:name, validate_name(Map.get(map, "name"))},
      {:email, validate_email(Map.get(map, "email"))},
      {:age, validate_age(Map.get(map, "age"))},
      {:joined_on, validate_joined_on(Map.get(map, "joined_on"))}
    ]
    |> Enum.reduce(%{data: %{}, errors: %{}}, fn {key, result}, acc ->
      case result do
        {:ok, value} -> %{acc | data: Map.put(acc.data, key, value)}
        {:error, message} -> %{acc | errors: Map.put(acc.errors, key, message)}
      end
    end)
    |> case do
      %{data: data, errors: errors} when errors == %{} ->
        {:ok, struct!(Member, data)}

      %{errors: errors} ->
        {:error, errors}
    end
  end

  def new(_), do: {:error, "invalid params"}

  @spec validate_name(String.t() | nil) :: validation_result(String.t())
  defp validate_name(nil), do: {:error, "is required"}

  defp validate_name(name) when is_binary(name) do
    cond do
      String.trim(name) == "" -> {:error, "can't be blank"}
      String.length(name) > 100 -> {:error, "must be at most 100 characters"}
      true -> {:ok, name}
    end
  end

  @spec validate_email(String.t() | nil) :: validation_result(String.t())
  defp validate_email(nil), do: {:error, "is required"}

  defp validate_email(email) when is_binary(email) do
    if String.match?(email, ~r/^[^@\s]+@[^@\s]+$/) do
      {:ok, email}
    else
      {:error, "is invalid"}
    end
  end

  @spec validate_age(String.t() | nil) :: validation_result(integer() | nil)
  defp validate_age(age) when age in [nil, ""], do: {:ok, nil}

  defp validate_age(age) when is_binary(age) do
    with {parsed, ""} <- Integer.parse(age), true <- parsed in 0..150 do
      {:ok, parsed}
    else
      _ -> {:error, "must be a positive integer between 0 and 150"}
    end
  end

  @spec validate_joined_on(String.t() | nil) :: validation_result(Date.t())
  defp validate_joined_on(date_string) when date_string in [nil, ""], do: {:ok, Date.utc_today()}

  defp validate_joined_on(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "must be yyyy-mm-dd string"}
    end
  end
end
