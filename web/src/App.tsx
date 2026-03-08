import { useEffect } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { MainLayout } from "./components/layout/MainLayout";
import { SettingsLayout } from "./components/layout/SettingsLayout";
import { useIsMobile } from "./hooks/useIsMobile";
import { HomePage } from "./pages/HomePage";
import { EmptyState } from "./pages/EmptyState";
import { MobileProjectsPage } from "./pages/MobileProjectsPage";
import { MobileBoardsPage } from "./pages/MobileBoardsPage";
import { MobileChatPage } from "./pages/MobileChatPage";
import { MobileDocFoldersPage } from "./pages/MobileDocFoldersPage";
import { ProjectPage } from "./pages/ProjectPage";
import { BoardView } from "./pages/BoardView";
import { DocFolderView } from "./pages/DocFolderView";
import { DocView } from "./pages/DocView";
import { ChatView } from "./pages/ChatView";
import { GeneralSettingsPage } from "./pages/GeneralSettingsPage";
import { AutomationSettingsPage } from "./pages/AutomationSettingsPage";
import { WorkspaceMembersPage } from "./pages/WorkspaceMembersPage";
import { RegisterPage } from "./pages/RegisterPage";
import { LoginPage } from "./pages/LoginPage";
import { VerifyEmailPage } from "./pages/VerifyEmailPage";
import { ForgotPasswordPage } from "./pages/ForgotPasswordPage";
import { ResetPasswordPage } from "./pages/ResetPasswordPage";
import { ToastContainer } from "./components/ui/Toast";
import { MemberProfileProvider } from "./contexts/MemberProfileContext";
import { useAuthStore } from "./stores/authStore";
import { useProjectStore } from "./stores/projectStore";
import { useBoardStore } from "./stores/boardStore";
import { useDocStore } from "./stores/docStore";
import { useDocFolderStore } from "./stores/docFolderStore";
import { useChatStore } from "./stores/chatStore";
import { useNotificationChannel } from "./hooks/useNotificationChannel";
import { UpdatesPage } from "./pages/UpdatesPage";
import { SearchModal } from "./components/features/SearchModal";
import { useSearchStore } from "./stores/searchStore";

function SettingsIndexRoute() {
  const isMobile = useIsMobile();
  if (isMobile) {
    return <SettingsLayout>{null}</SettingsLayout>;
  }
  return <Navigate to="/settings/general" replace />;
}

function ProjectsIndexRoute() {
  const isMobile = useIsMobile();
  return isMobile ? <MobileProjectsPage /> : <EmptyState />;
}

function BoardsIndexRoute() {
  const isMobile = useIsMobile();
  return isMobile ? <MobileBoardsPage /> : <EmptyState />;
}

function ChatIndexRoute() {
  const isMobile = useIsMobile();
  return isMobile ? <MobileChatPage /> : <EmptyState />;
}

function DocFoldersIndexRoute() {
  const isMobile = useIsMobile();
  return isMobile ? <MobileDocFoldersPage /> : <EmptyState />;
}

function App() {
  const { checkAuth, fetchMembers, isAuthenticated, isLoading, needsEmailVerification, user } =
    useAuthStore();
  const { fetchProjects } = useProjectStore();
  const { fetchBoards } = useBoardStore();
  const { fetchDocs } = useDocStore();
  const { fetchFolders: fetchDocFolders } = useDocFolderStore();
  const { fetchChannels, fetchDirectMessages } = useChatStore();

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  useEffect(() => {
    if (isAuthenticated) {
      fetchProjects();
      fetchBoards();
      fetchDocFolders();
      fetchDocs();
      fetchChannels();
      fetchDirectMessages();
      fetchMembers();
    }
  }, [
    isAuthenticated,
    fetchProjects,
    fetchBoards,
    fetchDocFolders,
    fetchDocs,
    fetchChannels,
    fetchDirectMessages,
    fetchMembers,
    user?.id,
  ]);

  // Connect to notification channel for real-time updates
  useNotificationChannel();

  // Global Cmd+K / Ctrl+K shortcut for search
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        const { isOpen, open, close } = useSearchStore.getState();
        if (isOpen) {
          close();
        } else {
          open();
        }
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  if (isLoading) {
    return (
      <>
        <div className="flex h-screen w-screen items-center justify-center bg-dark-bg">
          <div className="text-dark-text">Loading...</div>
        </div>
        <ToastContainer />
      </>
    );
  }

  // Show verify email page if user has session but email not verified
  if (needsEmailVerification) {
    return (
      <>
        <Routes>
          <Route path="/verify-email" element={<VerifyEmailPage />} />
          <Route path="*" element={<Navigate to="/verify-email" replace />} />
        </Routes>
        <ToastContainer />
      </>
    );
  }

  // Show auth pages without layout
  if (!isAuthenticated) {
    return (
      <>
        <Routes>
          <Route path="/" element={null} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/verify-email" element={<VerifyEmailPage />} />
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/reset-password" element={<ResetPasswordPage />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
        <ToastContainer />
      </>
    );
  }

  return (
    <MemberProfileProvider>
      <Routes>
        <Route path="/" element={null} />
        <Route
          path="/dashboard"
          element={
            <MainLayout>
              <HomePage />
            </MainLayout>
          }
        />
        <Route
          path="/updates"
          element={
            <MainLayout>
              <UpdatesPage />
            </MainLayout>
          }
        />
        <Route
          path="/projects"
          element={
            <MainLayout>
              <ProjectsIndexRoute />
            </MainLayout>
          }
        />
        <Route
          path="/projects/:id"
          element={
            <MainLayout>
              <ProjectPage />
            </MainLayout>
          }
        />
        {/* Nested routes for project items */}
        <Route
          path="/projects/:projectId/boards/:id"
          element={
            <MainLayout>
              <BoardView />
            </MainLayout>
          }
        />
        <Route
          path="/projects/:projectId/doc-folders/:id"
          element={
            <MainLayout>
              <DocFolderView />
            </MainLayout>
          }
        />
        <Route
          path="/projects/:projectId/doc-folders/:folderId/docs/:id"
          element={
            <MainLayout>
              <DocFolderView />
              <DocView />
            </MainLayout>
          }
        />
        <Route
          path="/projects/:projectId/docs/:id"
          element={
            <MainLayout>
              <DocView />
            </MainLayout>
          }
        />
        <Route
          path="/projects/:projectId/channels/:id"
          element={
            <MainLayout>
              <ChatView />
            </MainLayout>
          }
        />
        <Route
          path="/boards"
          element={
            <MainLayout>
              <BoardsIndexRoute />
            </MainLayout>
          }
        />
        <Route
          path="/boards/:id"
          element={
            <MainLayout>
              <BoardView />
            </MainLayout>
          }
        />
        <Route
          path="/doc-folders/:id"
          element={
            <MainLayout>
              <DocFolderView />
            </MainLayout>
          }
        />
        <Route
          path="/doc-folders/:folderId/docs/:id"
          element={
            <MainLayout>
              <DocFolderView />
              <DocView />
            </MainLayout>
          }
        />
        <Route
          path="/docs"
          element={
            <MainLayout>
              <EmptyState />
            </MainLayout>
          }
        />
        <Route
          path="/docs/:id"
          element={
            <MainLayout>
              <DocView />
            </MainLayout>
          }
        />
        <Route
          path="/channels"
          element={
            <MainLayout>
              <ChatIndexRoute />
            </MainLayout>
          }
        />
        <Route
          path="/channels/:id"
          element={
            <MainLayout>
              <ChatView />
            </MainLayout>
          }
        />
        <Route
          path="/doc-folders"
          element={
            <MainLayout>
              <DocFoldersIndexRoute />
            </MainLayout>
          }
        />
        <Route
          path="/dms"
          element={
            <MainLayout>
              <EmptyState />
            </MainLayout>
          }
        />
        <Route
          path="/dms/:id"
          element={
            <MainLayout>
              <ChatView />
            </MainLayout>
          }
        />
        <Route
          path="/settings"
          element={<SettingsIndexRoute />}
        />
        <Route
          path="/settings/general"
          element={
            <SettingsLayout>
              <GeneralSettingsPage />
            </SettingsLayout>
          }
        />
        <Route
          path="/settings/members"
          element={
            <SettingsLayout>
              <WorkspaceMembersPage />
            </SettingsLayout>
          }
        />
        <Route
          path="/settings/automation"
          element={
            <SettingsLayout>
              <AutomationSettingsPage />
            </SettingsLayout>
          }
        />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
      <SearchModal />
      <ToastContainer />
    </MemberProfileProvider>
  );
}

export default App;
