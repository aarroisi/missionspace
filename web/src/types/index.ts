// Role type
export type Role = "owner" | "member" | "guest";

// User types
export interface User {
  id: string;
  name: string;
  email: string;
  avatar: string;
  online: boolean;
  role: Role;
  insertedAt: string;
  updatedAt: string;
}

// Project member type
export interface ProjectMember {
  id: string;
  userId: string;
  projectId: string;
  user: User;
  insertedAt: string;
  updatedAt: string;
}

// Project types
export interface Project {
  id: string;
  name: string;
  description?: string;
  starred: boolean;
  startDate?: string;
  endDate?: string;
  items?: ProjectItem[];
  createdBy?: EmbeddedUser | null;
  insertedAt: string;
  updatedAt: string;
}

export interface ProjectItem {
  id: string;
  itemType: "board" | "doc" | "channel";
  itemId: string;
}

// Board Status type
export interface BoardStatus {
  id: string;
  name: string;
  color: string;
  position: number;
  isDone: boolean;
}

// Board types
export interface Board {
  id: string;
  name: string;
  starred: boolean;
  statuses?: BoardStatus[];
  createdById: string;
  createdBy?: EmbeddedUser | null;
  insertedAt: string;
  updatedAt: string;
}

// Embedded user info (for assignee, created_by, etc.)
export interface EmbeddedUser {
  id: string;
  name: string;
  email: string;
}

export interface Task {
  id: string;
  boardId: string;
  title: string;
  statusId: string;
  status?: BoardStatus;
  position: number;
  assigneeId?: string | null;
  assignee?: EmbeddedUser | null;
  createdById: string;
  createdBy?: EmbeddedUser | null;
  dueOn?: string | null;
  completedAt?: string | null;
  notes?: string | null;
  subtaskCount: number;
  subtaskDoneCount: number;
  commentCount: number;
  insertedAt: string;
  updatedAt: string;
}

export interface Subtask {
  id: string;
  taskId: string;
  isCompleted: boolean;
  title: string;
  assigneeId?: string | null;
  assignee?: EmbeddedUser | null;
  createdById: string;
  createdBy?: EmbeddedUser | null;
  notes?: string | null;
  dueOn?: string | null;
  completedAt?: string | null;
  insertedAt: string;
  updatedAt: string;
  // Optional task info (included when fetching subtasks with task preloaded)
  task?: {
    id: string;
    boardId: string;
    title: string;
  };
}

// Doc types
export interface Doc {
  id: string;
  title: string;
  content: string;
  createdBy?: EmbeddedUser | null;
  starred: boolean;
  insertedAt: string;
  updatedAt: string;
}

// Chat types
export interface Channel {
  id: string;
  name: string;
  starred: boolean;
  insertedAt: string;
  updatedAt: string;
}

export interface DirectMessage {
  id: string;
  name: string;
  userId: string;
  avatar: string;
  online: boolean;
  starred: boolean;
  insertedAt: string;
  updatedAt: string;
}

// Message/Comment types (universal)
export interface Message {
  id: string;
  userId: string;
  userName: string;
  avatar: string;
  text: string;
  parentId?: string; // For threading
  quoteId?: string; // For quotes
  quote?: Message; // The actual quoted message
  entityType: "task" | "subtask" | "doc" | "channel" | "dm";
  entityId: string;
  insertedAt: string;
  updatedAt: string;
}

// Pagination types
export interface PaginationMetadata {
  after: string | null;
  before: string | null;
  limit: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  metadata: PaginationMetadata;
}

// View modes
export type ViewMode = "board" | "list";

// Category types
export type Category =
  | "home"
  | "projects"
  | "boards"
  | "docs"
  | "channels"
  | "dms";

// Active item type
export interface ActiveItem {
  type: Category;
  id?: string;
}

// Notification types
export interface Notification {
  id: string;
  type: "mention";
  entityType: "message" | "doc" | "task" | "subtask";
  entityId: string;
  context: Record<string, unknown>;
  read: boolean;
  userId: string;
  actorId: string;
  actorName?: string;
  actorAvatar?: string;
  insertedAt: string;
  updatedAt: string;
}
