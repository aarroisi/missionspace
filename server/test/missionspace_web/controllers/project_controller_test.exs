defmodule MissionspaceWeb.ProjectControllerTest do
  use MissionspaceWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user}
  end

  describe "index" do
    test "returns all projects in workspace", %{conn: conn, workspace: workspace} do
      project1 = insert(:project, workspace_id: workspace.id)
      project2 = insert(:project, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      project_ids = Enum.map(response["data"], & &1["id"])
      assert project1.id in project_ids
      assert project2.id in project_ids
    end

    test "does not return projects from other workspaces", %{conn: conn, workspace: workspace} do
      other_workspace = insert(:workspace)
      _project_in_workspace = insert(:project, workspace_id: workspace.id)
      other_project = insert(:project, workspace_id: other_workspace.id)

      response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      project_ids = Enum.map(response["data"], & &1["id"])
      refute other_project.id in project_ids
    end

    test "returns empty list when no projects exist", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns paginated results with correct metadata", %{conn: conn, workspace: workspace} do
      # Create 5 projects
      for _ <- 1..5 do
        insert(:project, workspace_id: workspace.id)
      end

      response =
        conn
        |> get(~p"/api/projects?limit=2")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["metadata"]["limit"] == 2
      assert is_binary(response["metadata"]["after"]) or is_nil(response["metadata"]["after"])
      assert is_nil(response["metadata"]["before"])
    end
  end

  describe "create" do
    test "creates project with valid attributes", %{conn: conn} do
      project_params = %{
        name: "New Project",
        starred: false
      }

      response =
        conn
        |> post(~p"/api/projects", project_params)
        |> json_response(201)

      assert response["data"]["name"] == "New Project"
      assert response["data"]["starred"] == false
      assert response["data"]["id"]
    end

    test "created project appears in index", %{conn: conn} do
      project_params = %{
        name: "Test Project"
      }

      create_response =
        conn
        |> post(~p"/api/projects", project_params)
        |> json_response(201)

      project_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      project_ids = Enum.map(index_response["data"], & &1["id"])
      assert project_id in project_ids
    end

    test "returns error with invalid attributes", %{conn: conn} do
      project_params = %{
        name: ""
      }

      response =
        conn
        |> post(~p"/api/projects", project_params)
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "sets workspace to current user's workspace", %{
      conn: conn,
      workspace: workspace
    } do
      other_workspace = insert(:workspace)

      project_params = %{
        name: "Test Project"
      }

      create_response =
        conn
        |> post(~p"/api/projects", project_params)
        |> json_response(201)

      project_id = create_response["data"]["id"]

      # Verify the project appears in current workspace's list
      index_response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      project_ids = Enum.map(index_response["data"], & &1["id"])
      assert project_id in project_ids

      # Verify it's actually stored with the correct workspace_id by checking
      # it doesn't appear for another workspace
      project = Missionspace.Repo.get!(Missionspace.Projects.Project, project_id)
      assert project.workspace_id == workspace.id
      refute project.workspace_id == other_workspace.id
    end
  end

  describe "show" do
    test "returns project by id", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/projects/#{project.id}")
        |> json_response(200)

      assert response["data"]["id"] == project.id
      assert response["data"]["name"] == project.name
      assert response["data"]["starred"] == project.starred
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      conn
      |> get(~p"/api/projects/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 for project from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_project = insert(:project, workspace_id: other_workspace.id)

      conn
      |> get(~p"/api/projects/#{other_project.id}")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates project with valid attributes", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id, name: "Old Name")

      update_params = %{
        name: "New Name"
      }

      response =
        conn
        |> put(~p"/api/projects/#{project.id}", update_params)
        |> json_response(200)

      assert response["data"]["name"] == "New Name"
    end

    test "updated project reflects changes in show", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id, name: "Old Name")

      update_params = %{name: "Updated Name"}

      conn
      |> put(~p"/api/projects/#{project.id}", update_params)
      |> json_response(200)

      show_response =
        conn
        |> get(~p"/api/projects/#{project.id}")
        |> json_response(200)

      assert show_response["data"]["name"] == "Updated Name"
    end

    test "returns error with invalid attributes", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id)

      update_params = %{
        name: ""
      }

      response =
        conn
        |> put(~p"/api/projects/#{project.id}", update_params)
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      update_params = %{name: "New Name"}

      conn
      |> put(~p"/api/projects/00000000-0000-0000-0000-000000000000", update_params)
      |> json_response(404)
    end

    test "returns 404 when updating project from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_project = insert(:project, workspace_id: other_workspace.id)

      update_params = %{name: "Hacked Name"}

      conn
      |> put(~p"/api/projects/#{other_project.id}", update_params)
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes project", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/projects/#{project.id}")
      |> response(204)
    end

    test "deleted project no longer appears in index", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/projects/#{project.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/projects")
        |> json_response(200)

      project_ids = Enum.map(index_response["data"], & &1["id"])
      refute project.id in project_ids
    end

    test "deleted project returns 404 on show", %{conn: conn, workspace: workspace} do
      project = insert(:project, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/projects/#{project.id}")
      |> response(204)

      conn
      |> get(~p"/api/projects/#{project.id}")
      |> json_response(404)
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      conn
      |> delete(~p"/api/projects/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 when deleting project from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_project = insert(:project, workspace_id: other_workspace.id)

      conn
      |> delete(~p"/api/projects/#{other_project.id}")
      |> json_response(404)
    end
  end
end
