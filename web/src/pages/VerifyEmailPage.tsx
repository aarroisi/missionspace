import { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Mail, CheckCircle, Loader2 } from "lucide-react";
import { API_URL } from "@/lib/api";

export function VerifyEmailPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token");
  const { success, error: showError } = useToastStore();

  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState("");

  // If token is in URL, verify it automatically
  useEffect(() => {
    if (token) {
      verifyToken(token);
    }
  }, [token]);

  const verifyToken = async (t: string) => {
    setVerifying(true);
    setError("");
    try {
      const response = await fetch(`${API_URL}/auth/verify-email`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ token: t }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Verification failed");
      }

      setVerified(true);
      success("Email verified successfully!");
      // Clear the verification flag so App doesn't redirect back here
      useAuthStore.setState({ needsEmailVerification: false });
      setTimeout(() => navigate("/login"), 2000);
    } catch (err) {
      setError((err as Error).message);
      showError((err as Error).message);
    } finally {
      setVerifying(false);
    }
  };

  const handleResend = async () => {
    setResending(true);
    setError("");
    try {
      const response = await fetch(`${API_URL}/auth/resend-verification`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to resend");
      }

      success("Verification email sent!");
    } catch (err) {
      setError((err as Error).message);
      showError((err as Error).message);
    } finally {
      setResending(false);
    }
  };

  // Token verification in progress
  if (verifying) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-bg px-4">
        <div className="max-w-md w-full text-center">
          <Loader2 size={48} className="animate-spin text-blue-400 mx-auto mb-4" />
          <p className="text-dark-text">Verifying your email...</p>
        </div>
      </div>
    );
  }

  // Verified successfully
  if (verified) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-bg px-4">
        <div className="max-w-md w-full text-center">
          <CheckCircle size={48} className="text-green-400 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-dark-text mb-2">
            Email Verified!
          </h1>
          <p className="text-dark-text-muted mb-4">
            Redirecting you to sign in...
          </p>
        </div>
      </div>
    );
  }

  // Default: waiting for verification (no token in URL)
  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-bg px-4">
      <div className="max-w-md w-full text-center">
        <div className="w-16 h-16 rounded-full bg-blue-500/10 flex items-center justify-center mx-auto mb-6">
          <Mail size={32} className="text-blue-400" />
        </div>
        <h1 className="text-2xl font-bold text-dark-text mb-2">
          Check your inbox
        </h1>
        <p className="text-dark-text-muted mb-6">
          We sent a verification link to your email address.
          Click the link to verify your account.
        </p>

        {error && (
          <div className="bg-red-900/20 border border-red-500 text-red-200 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        <button
          onClick={handleResend}
          disabled={resending}
          className="px-4 py-2 text-sm text-blue-400 hover:text-blue-300 transition-colors disabled:opacity-50"
        >
          {resending ? "Sending..." : "Didn't receive it? Resend verification email"}
        </button>

        <div className="mt-6">
          <button
            onClick={() => navigate("/login")}
            className="text-sm text-dark-text-muted hover:text-dark-text transition-colors"
          >
            Back to sign in
          </button>
        </div>
      </div>
    </div>
  );
}
