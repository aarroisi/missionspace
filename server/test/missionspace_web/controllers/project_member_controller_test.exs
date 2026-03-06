defmodule MissionspaceWeb.ProjectMemberControllerTest do
  use MissionspaceWeb.ConnCase

  describe "index" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")
      project = insert(:project, workspace_id: workspace.id)
      insert(:project_member, user_id: member.id, project_id: project.id)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner, member: member, project: project}
    end

    test "lists project members for owner", %{conn: conn, project: project, member: member} do
      response =
        conn
        |> get(~p"/api/projects/#{project.id}/members")
        |> json_response(200)

      user_ids = Enum.map(response["data"], & &1["userId"])
      assert member.id in user_ids
    end

    test "returns 403 for non-owners", %{conn: conn, project: project, member: member} do
      conn =
        conn
        |> put_session(:user_id, member.id)

      conn
      |> get(~p"/api/projects/#{project.id}/members")
      |> json_response(403)
    end
  end

  describe "create" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")
      project = insert(:project, workspace_id: workspace.id)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner, member: member, project: project}
    end

    test "adds member to project", %{conn: conn, project: project, member: member} do
      response =
        conn
        |> post(~p"/api/projects/#{project.id}/members", user_id: member.id)
        |> json_response(201)

      assert response["data"]["userId"] == member.id
      assert response["data"]["projectId"] == project.id
    end

    test "returns error for duplicate membership", %{conn: conn, project: project, member: member} do
      insert(:project_member, user_id: member.id, project_id: project.id)

      conn
      |> post(~p"/api/projects/#{project.id}/members", user_id: member.id)
      |> json_response(422)
    end

    test "returns 403 for non-owners", %{conn: conn, project: project, member: member} do
      other_member = insert(:user, workspace_id: project.workspace_id, role: "member")

      conn =
        conn
        |> put_session(:user_id, member.id)

      conn
      |> post(~p"/api/projects/#{project.id}/members", user_id: other_member.id)
      |> json_response(403)
    end

    test "enforces guest can only be in one project", %{conn: conn, workspace: workspace} do
      guest = insert(:user, workspace_id: workspace.id, role: "guest")
      project1 = insert(:project, workspace_id: workspace.id)
      project2 = insert(:project, workspace_id: workspace.id)

      # Add guest to first project
      conn
      |> post(~p"/api/projects/#{project1.id}/members", user_id: guest.id)
      |> json_response(201)

      # Try to add guest to second project - should fail
      response =
        conn
        |> post(~p"/api/projects/#{project2.id}/members", user_id: guest.id)
        |> json_response(422)

      assert response["errors"]["user_id"]
    end
  end

  describe "delete" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")
      project = insert(:project, workspace_id: workspace.id)
      project_member = insert(:project_member, user_id: member.id, project_id: project.id)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok,
       conn: conn,
       workspace: workspace,
       owner: owner,
       member: member,
       project: project,
       project_member: project_member}
    end

    test "removes member from project", %{conn: conn, project: project, member: member} do
      conn
      |> delete(~p"/api/projects/#{project.id}/members/#{member.id}")
      |> response(204)
    end

    test "returns 404 for non-existent membership", %{
      conn: conn,
      project: project,
      workspace: workspace
    } do
      other_user = insert(:user, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/projects/#{project.id}/members/#{other_user.id}")
      |> json_response(404)
    end

    test "returns 403 for non-owners", %{conn: conn, project: project, member: member} do
      conn =
        conn
        |> put_session(:user_id, member.id)

      conn
      |> delete(~p"/api/projects/#{project.id}/members/#{member.id}")
      |> json_response(403)
    end
  end
end
