defmodule Missionspace.Automation.GitHubApp do
  @moduledoc false

  @default_api_base_url "https://api.github.com"
  @github_api_version "2022-11-28"
  @default_per_page 100

  @spec create_installation_token(String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_installation_token(installation_id) when is_binary(installation_id) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, jwt} <- sign_app_jwt(config.app_id, config.private_key_pem),
         {:ok, body} <- request_installation_token(config.api_base_url, installation_id, jwt),
         {:ok, token} <- extract_installation_token(body) do
      {:ok, token}
    end
  end

  def create_installation_token(_installation_id), do: {:error, :invalid_installation_id}

  @spec delete_installation(String.t()) :: :ok | {:error, term()}
  def delete_installation(installation_id) when is_binary(installation_id) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, jwt} <- sign_app_jwt(config.app_id, config.private_key_pem),
         :ok <- request_delete_installation(config.api_base_url, installation_id, jwt) do
      :ok
    end
  end

  def delete_installation(_installation_id), do: {:error, :invalid_installation_id}

  @spec get_installation_details(String.t()) :: {:ok, map()} | {:error, term()}
  def get_installation_details(installation_id) when is_binary(installation_id) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, jwt} <- sign_app_jwt(config.app_id, config.private_key_pem),
         {:ok, body} <- request_installation_details(config.api_base_url, installation_id, jwt),
         {:ok, details} <- extract_installation_details(body) do
      {:ok, details}
    end
  end

  def get_installation_details(_installation_id), do: {:error, :invalid_installation_id}

  @spec list_installation_repositories(String.t()) :: {:ok, list(map())} | {:error, term()}
  def list_installation_repositories(installation_id) when is_binary(installation_id) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, token} <- create_installation_token(installation_id) do
      list_installation_repositories(config.api_base_url, token, 1, [])
    end
  end

  def list_installation_repositories(_installation_id), do: {:error, :invalid_installation_id}

  defp fetch_runtime_config do
    github_app_config = Application.get_env(:missionspace, :github_app, [])

    app_id =
      github_app_config
      |> Keyword.get(:app_id)
      |> to_string_if_present()

    private_key_pem =
      github_app_config
      |> Keyword.get(:private_key_pem)
      |> to_string_if_present()
      |> normalize_private_key_pem()

    api_base_url =
      github_app_config
      |> Keyword.get(:api_base_url, @default_api_base_url)
      |> to_string_if_present()
      |> default_if_nil(@default_api_base_url)

    cond do
      is_nil(app_id) ->
        {:error, :github_app_not_configured}

      is_nil(private_key_pem) ->
        {:error, :github_app_not_configured}

      true ->
        {:ok, %{app_id: app_id, private_key_pem: private_key_pem, api_base_url: api_base_url}}
    end
  end

  defp sign_app_jwt(app_id, private_key_pem) do
    now = System.os_time(:second)

    claims = %{
      "iss" => app_id,
      "iat" => now - 60,
      "exp" => now + 9 * 60
    }

    try do
      jwk = JOSE.JWK.from_pem(private_key_pem)

      {_jws, token} =
        JOSE.JWT.sign(jwk, %{"alg" => "RS256"}, claims)
        |> JOSE.JWS.compact()

      {:ok, token}
    rescue
      _ -> {:error, :invalid_github_app_private_key}
    end
  end

  defp request_installation_token(api_base_url, installation_id, jwt) do
    url =
      api_base_url
      |> String.trim_trailing("/")
      |> Kernel.<>("/app/installations/#{installation_id}/access_tokens")

    case Req.post(
           url: url,
           headers: [
             {"authorization", "Bearer #{jwt}"},
             {"accept", "application/vnd.github+json"},
             {"x-github-api-version", @github_api_version}
           ],
           json: %{}
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:github_request_failed, status}}

      {:error, reason} ->
        {:error, {:github_request_failed, reason}}
    end
  end

  defp request_installation_details(api_base_url, installation_id, jwt) do
    url =
      api_base_url
      |> String.trim_trailing("/")
      |> Kernel.<>("/app/installations/#{installation_id}")

    case Req.get(
           url: url,
           headers: [
             {"authorization", "Bearer #{jwt}"},
             {"accept", "application/vnd.github+json"},
             {"x-github-api-version", @github_api_version}
           ]
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:github_request_failed, status}}

      {:error, reason} ->
        {:error, {:github_request_failed, reason}}
    end
  end

  defp request_delete_installation(api_base_url, installation_id, jwt) do
    url =
      api_base_url
      |> String.trim_trailing("/")
      |> Kernel.<>("/app/installations/#{installation_id}")

    case Req.delete(
           url: url,
           headers: [
             {"authorization", "Bearer #{jwt}"},
             {"accept", "application/vnd.github+json"},
             {"x-github-api-version", @github_api_version}
           ]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 202, 204, 404] ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        {:error, {:github_request_failed, status}}

      {:error, reason} ->
        {:error, {:github_request_failed, reason}}
    end
  end

  defp list_installation_repositories(api_base_url, token, page, acc) do
    url =
      api_base_url
      |> String.trim_trailing("/")
      |> Kernel.<>("/installation/repositories?per_page=#{@default_per_page}&page=#{page}")

    case Req.get(
           url: url,
           headers: [
             {"authorization", "token #{token}"},
             {"accept", "application/vnd.github+json"},
             {"x-github-api-version", @github_api_version}
           ]
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        repositories =
          body
          |> read_map_value(["repositories", :repositories])
          |> normalize_installation_repositories()

        all_repositories = acc ++ repositories

        if length(repositories) < @default_per_page do
          {:ok, all_repositories}
        else
          list_installation_repositories(api_base_url, token, page + 1, all_repositories)
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:github_request_failed, status}}

      {:error, reason} ->
        {:error, {:github_request_failed, reason}}
    end
  end

  defp normalize_installation_repositories(repositories) when is_list(repositories) do
    repositories
    |> Enum.map(&normalize_installation_repository/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_installation_repositories(_), do: []

  defp normalize_installation_repository(repository) when is_map(repository) do
    owner_login =
      repository
      |> read_map_value(["owner", :owner])
      |> read_map_value(["login", :login])
      |> to_string_if_present()

    repo_name =
      repository
      |> read_map_value(["name", :name])
      |> to_string_if_present()

    default_branch =
      repository
      |> read_map_value(["default_branch", :default_branch])
      |> to_string_if_present()
      |> default_if_nil("main")

    if is_binary(owner_login) and is_binary(repo_name) do
      %{
        "provider" => "github",
        "repo_owner" => owner_login,
        "repo_name" => repo_name,
        "default_branch" => default_branch,
        "enabled" => true
      }
    else
      nil
    end
  end

  defp normalize_installation_repository(_), do: nil

  defp extract_installation_details(body) when is_map(body) do
    account = read_map_value(body, ["account", :account])

    installation_id =
      body
      |> read_map_value(["id", :id])
      |> to_string_if_present()

    {:ok,
     %{
       installation_id: installation_id,
       account_login:
         account
         |> read_map_value(["login", :login])
         |> to_string_if_present(),
       account_type:
         account
         |> read_map_value(["type", :type])
         |> to_string_if_present(),
       account_avatar_url:
         account
         |> read_map_value(["avatar_url", :avatar_url])
         |> to_string_if_present(),
       account_url:
         account
         |> read_map_value(["html_url", :html_url])
         |> to_string_if_present(),
       app_slug:
         body
         |> read_map_value(["app_slug", :app_slug])
         |> to_string_if_present(),
       repository_selection:
         body
         |> read_map_value(["repository_selection", :repository_selection])
         |> to_string_if_present()
     }}
  end

  defp extract_installation_details(_), do: {:error, :invalid_github_installation_response}

  defp read_map_value(map, keys) when is_map(map) and is_list(keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp read_map_value(_map, _keys), do: nil

  defp extract_installation_token(%{"token" => token}) when is_binary(token), do: {:ok, token}
  defp extract_installation_token(%{token: token}) when is_binary(token), do: {:ok, token}
  defp extract_installation_token(_), do: {:error, :invalid_github_installation_token_response}

  defp to_string_if_present(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp to_string_if_present(value) when is_integer(value), do: Integer.to_string(value)
  defp to_string_if_present(_), do: nil

  defp normalize_private_key_pem(nil), do: nil

  defp normalize_private_key_pem(private_key_pem) when is_binary(private_key_pem) do
    private_key_pem
    |> String.replace("\\n", "\n")
    |> String.trim()
  end

  defp default_if_nil(nil, default), do: default
  defp default_if_nil(value, _default), do: value
end
