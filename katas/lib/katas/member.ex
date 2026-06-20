defmodule Katas.Member do
  alias Katas.Member
  @enforce_keys [:name, :email]
  defstruct [:name, :email, :age, joined_on: Date.utc_today()]

  @type validation_result(value) :: {:ok, value} | {:error, String.t()}

  @spec new(%{name: String.t(), email: String.t(), age: String.t(), joined_on: String.t()}) ::
          {:ok, %Member{}} | {:error, %{atom() => String.t()}}
  @doc """
  `Member.new(map_with_string_keys)` returns `{:ok, %Member{}}` or `{:error, errors}` where `errors` is a map like `%{age: "must be a positive integer", email: "is invalid"}`
  """
  def new(%{name: name, email: email, age: age, joined_on: joined_on})
      when is_binary(name) and
             is_binary(email) and
             (is_binary(age) or is_nil(age)) and
             (is_binary(joined_on) or is_nil(joined_on)) do
    [
      {:email, validate_email(email)},
      {:age, validate_age(age)},
      {:joined_on, validate_joined_on(joined_on)}
    ]
    |> Enum.reduce(%{data: %{name: name}, errors: %{}}, fn {key, result}, acc ->
      result
      |> case do
        {:ok, value} -> Map.put(acc, :data, Map.put(acc.data, key, value))
        {:error, message} -> Map.put(acc, :errors, Map.put(acc.errors, key, message))
      end
    end)
    |> case do
      %{data: %{name: name, email: email, age: age, joined_on: joined_on}} ->
        {:ok, %Member{name: name, email: email, age: age, joined_on: joined_on}}

      %{data: _, errors: errors} ->
        {:error, errors}
    end
  end

  def new(_) do
    {:error, "invalid params"}
  end

  @spec validate_email(String.t()) :: validation_result(String.t())
  defp validate_email(email) when is_binary(email) do
    email
    |> String.match?(~r/^[A-Za-z0-9._%+\-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/)
    |> case do
      true -> {:ok, email}
      _ -> {:error, "is invalid"}
    end
  end

  @spec validate_age(String.t() | nil) :: validation_result(integer())
  defp validate_age(age) when is_binary(age) or is_nil(age) do
    with {age_parsed, ""} <- Integer.parse(age), true <- age_parsed in 0..150 do
      {:ok, age_parsed}
    else
      _ -> {:error, "must be a positive integer between 0 and 150"}
    end
  end

  @spec validate_joined_on(String.t() | nil) :: validation_result(Calendar.date())
  defp validate_joined_on(date_string) when is_binary(date_string) or is_nil(date_string) do
    if date_string == nil do
      {:ok, Date.utc_today()}
    else
      date_string
      |> Date.from_iso8601()
      |> case do
        {:ok, date} -> {:ok, date}
        _ -> {:error, "must be yyyy-mm-dd string"}
      end
    end
  end
end
