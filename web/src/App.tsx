import { useEffect } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { MainLayout } from "./components/layout/MainLayout";
import { SettingsLayout } from "./components/layout/SettingsLayout";
import { HomePage } from "./pages/HomePage";
import { EmptyState } from "./pages/EmptyState";
import { ProjectPage } from "./pages/ProjectPage";
import { BoardView } from "./pages/BoardView";
import { DocFolderView } from "./pages/DocFolderView";
import { DocView } from "./pages/DocView";
import { ChatView } from "./pages/ChatView";
import { GeneralSettingsPage } from "./pages/GeneralSettingsPage";
import { WorkspaceMembersPage } from "./pages/WorkspaceMembersPage";
import { RegisterPage } from "./pages/RegisterPage";
import { LoginPage } from "./pages/LoginPage";
import { ToastContainer } from "./components/ui/Toast";
import { MemberProfileProvider } from "./contexts/MemberProfileContext";
import { useAuthStore } from "./stores/authStore";
import { useProjectStore } from "./stores/projectStore";
import { useBoardStore } from "./stores/boardStore";
import { useDocStore } from "./stores/docStore";
import { useDocFolderStore } from "./stores/docFolderStore";
import { useChatStore } from "./stores/chatStore";
import { useNotificationChannel } from "./hooks/useNotificationChannel";
import { SearchModal } from "./components/features/SearchModal";
import { useSearchStore } from "./stores/searchStore";

function App() {
  const { checkAuth, fetchMembers, isAuthenticated, isLoading } =
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

  // Show auth pages without layout
  if (!isAuthenticated) {
    return (
      <>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
        <ToastContainer />
      </>
    );
  }

  return (
    <MemberProfileProvider>
      <Routes>
        <Route
          path="/"
          element={
            <MainLayout>
              <HomePage />
            </MainLayout>
          }
        />
        <Route
          path="/projects"
          element={
            <MainLayout>
              <EmptyState />
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
              <EmptyState />
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
              <EmptyState />
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
          element={<Navigate to="/settings/general" replace />}
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
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <SearchModal />
      <ToastContainer />
    </MemberProfileProvider>
  );
}

export default App;
