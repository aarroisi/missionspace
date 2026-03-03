defmodule Bridge.Emails do
  import Swoosh.Email

  @from_name "Bridge"

  defp from_email do
    Application.get_env(:bridge, :from_email, "noreply@bridgework.com")
  end

  defp frontend_url do
    Application.get_env(:bridge, :frontend_url, "http://localhost:5173")
  end

  def verification_email(user) do
    url = "#{frontend_url()}/verify-email?token=#{user.email_verification_token}"

    new()
    |> to({user.name, user.email})
    |> from({@from_name, from_email()})
    |> subject("Verify your email address")
    |> html_body("""
    <h2>Welcome to Bridge, #{user.name}!</h2>
    <p>Please verify your email address by clicking the link below:</p>
    <p><a href="#{url}">Verify Email Address</a></p>
    <p>If you didn't create an account, you can safely ignore this email.</p>
    """)
    |> text_body("""
    Welcome to Bridge, #{user.name}!

    Please verify your email address by visiting this link:
    #{url}

    If you didn't create an account, you can safely ignore this email.
    """)
  end

  def password_reset_email(user) do
    url = "#{frontend_url()}/reset-password?token=#{user.password_reset_token}"

    new()
    |> to({user.name, user.email})
    |> from({@from_name, from_email()})
    |> subject("Reset your password")
    |> html_body("""
    <h2>Password Reset</h2>
    <p>We received a request to reset your password. Click the link below to set a new one:</p>
    <p><a href="#{url}">Reset Password</a></p>
    <p>This link will expire in 1 hour.</p>
    <p>If you didn't request this, you can safely ignore this email.</p>
    """)
    |> text_body("""
    Password Reset

    We received a request to reset your password. Visit this link to set a new one:
    #{url}

    This link will expire in 1 hour.

    If you didn't request this, you can safely ignore this email.
    """)
  end
end
