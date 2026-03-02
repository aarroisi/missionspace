defmodule BridgeWeb.Router do
  use BridgeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
  end

  pipeline :authenticated do
    plug(BridgeWeb.Plugs.AuthPlug)
  end

  scope "/api", BridgeWeb do
    pipe_through(:api)

    # Auth routes (no authentication required)
    post("/auth/register", AuthController, :register)
    post("/auth/login", AuthController, :login)
    post("/auth/logout", AuthController, :logout)
    get("/auth/me", AuthController, :me)
  end

  scope "/api", BridgeWeb do
    pipe_through([:api, :authenticated])

    # Auth routes (authentication required)
    put("/auth/me", AuthController, :update_me)

    # Workspace settings (owner only)
    put("/workspace", WorkspaceController, :update)

    # Workspace member management (owner only)
    resources("/workspace/members", WorkspaceMemberController, except: [:new, :edit])

    # Project member management (owner only)
    resources("/projects/:project_id/members", ProjectMemberController,
      only: [:index, :create, :delete]
    )

    # Project item management (owner only)
    resources("/projects/:project_id/items", ProjectItemController,
      only: [:index, :create, :delete]
    )

    # Item member management
    get("/item-members/:item_type/:item_id", ItemMemberController, :index)
    post("/item-members/:item_type/:item_id", ItemMemberController, :create)
    delete("/item-members/:item_type/:item_id/:user_id", ItemMemberController, :delete)

    # Resource routes (authentication required)
    resources("/projects", ProjectController, except: [:new, :edit])
    get("/boards/suggest-prefix", ListController, :suggest_prefix)
    get("/boards/check-prefix", ListController, :check_prefix)
    resources("/boards", ListController, except: [:new, :edit])
    get("/boards/:list_id/statuses", ListStatusController, :index)
    post("/boards/:list_id/statuses", ListStatusController, :create)
    put("/boards/:list_id/statuses/reorder", ListStatusController, :reorder)
    patch("/statuses/:id", ListStatusController, :update)
    delete("/statuses/:id", ListStatusController, :delete)
    resources("/tasks", TaskController, except: [:new, :edit])
    put("/tasks/:id/reorder", TaskController, :reorder)
    get("/doc-folders/suggest-prefix", DocFolderController, :suggest_prefix)
    get("/doc-folders/check-prefix", DocFolderController, :check_prefix)
    resources("/doc-folders", DocFolderController, except: [:new, :edit])
    resources("/docs", DocController, except: [:new, :edit])
    resources("/channels", ChannelController, except: [:new, :edit])
    resources("/direct_messages", DirectMessageController, except: [:new, :edit])
    resources("/messages", MessageController, except: [:new, :edit])

    # Star toggle (per-user)
    post("/stars/toggle", StarController, :toggle)

    # Search
    get("/search", SearchController, :index)

    # Notification routes
    get("/notifications", NotificationController, :index)
    patch("/notifications/:id/read", NotificationController, :mark_as_read)
    post("/notifications/read-all", NotificationController, :mark_all_as_read)
    get("/notifications/unread-count", NotificationController, :unread_count)

    # Asset routes
    post("/assets/request-upload", AssetController, :request_upload)
    post("/assets/:id/confirm", AssetController, :confirm)
    get("/assets/:id", AssetController, :show)
    delete("/assets/:id", AssetController, :delete)
    get("/workspace/storage", AssetController, :storage)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bridge, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: BridgeWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
