defmodule MissionspaceWeb.Router do
  use MissionspaceWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
  end

  pipeline :authenticated do
    plug(MissionspaceWeb.Plugs.AuthPlug)
  end

  # Health check (no auth, no pipeline)
  scope "/", MissionspaceWeb do
    get("/health", HealthController, :index)
  end

  scope "/api", MissionspaceWeb do
    pipe_through(:api)

    # Auth routes (no authentication required)
    post("/auth/register", AuthController, :register)
    post("/auth/login", AuthController, :login)
    post("/auth/logout", AuthController, :logout)
    get("/auth/me", AuthController, :me)
    get("/auth/accounts", AuthController, :accounts)
    delete("/auth/accounts/:user_id", AuthController, :remove_account)
    post("/auth/switch-account", AuthController, :switch_account)
    post("/auth/sign-out-account", AuthController, :sign_out_account)
    post("/auth/reauth-account", AuthController, :reauth_account)
    post("/auth/verify-email", AuthController, :verify_email)
    post("/auth/forgot-password", AuthController, :forgot_password)
    post("/auth/reset-password", AuthController, :reset_password)
  end

  scope "/api", MissionspaceWeb do
    pipe_through([:api, :authenticated])

    # Auth routes (authentication required)
    put("/auth/me", AuthController, :update_me)
    post("/auth/resend-verification", AuthController, :resend_verification)
    post("/auth/add-account", AuthController, :add_account)

    # API keys (user scoped)
    get("/api-keys/verify", ApiKeyController, :verify)
    get("/api-keys/scopes", ApiKeyController, :scopes)
    resources("/api-keys", ApiKeyController, only: [:index, :create, :delete])

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

    # Subscription routes
    get("/subscriptions/:item_type/:item_id", SubscriptionController, :index)
    get("/subscriptions/:item_type/:item_id/status", SubscriptionController, :status)
    post("/subscriptions/:item_type/:item_id", SubscriptionController, :create)
    delete("/subscriptions/:item_type/:item_id", SubscriptionController, :delete)

    # Read position routes (unread indicators)
    get("/read-positions/unread", ReadPositionController, :unread)
    get("/read-positions/:item_type/:item_id", ReadPositionController, :show)
    post("/read-positions/:item_type/:item_id", ReadPositionController, :create)

    # Push notification routes
    get("/push/vapid-key", PushSubscriptionController, :vapid_key)
    post("/push/subscribe", PushSubscriptionController, :subscribe)
    delete("/push/subscribe", PushSubscriptionController, :unsubscribe)

    # Asset routes
    post("/assets/request-upload", AssetController, :request_upload)
    post("/assets/:id/confirm", AssetController, :confirm)
    get("/assets/:id", AssetController, :show)
    delete("/assets/:id", AssetController, :delete)
    get("/workspace/storage", AssetController, :storage)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:missionspace, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: MissionspaceWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
