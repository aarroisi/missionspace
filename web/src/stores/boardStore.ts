import { create } from "zustand";
import { Board, BoardStatus, Task, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";
import { celebrateTaskCompletion } from "@/lib/confetti";

function insertStatusKeepingDoneLast(
  existingStatuses: BoardStatus[] | undefined,
  createdStatus: BoardStatus,
): BoardStatus[] {
  const currentStatuses = existingStatuses || [];

  const adjustedStatuses = currentStatuses.map((status) => {
    if (status.isDone && !createdStatus.isDone && status.position >= createdStatus.position) {
      return { ...status, position: status.position + 1 };
    }

    return status;
  });

  return [...adjustedStatuses, createdStatus].sort((a, b) => {
    if (a.isDone && !b.isDone) return 1;
    if (!a.isDone && b.isDone) return -1;
    return a.position - b.position;
  });
}

interface BoardState {
  boards: Board[];
  tasks: Record<string, Task[]>;
  childTasks: Record<string, Task[]>;
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;

  // Board operations
  fetchBoards: (loadMore?: boolean) => Promise<void>;
  createBoard: (name: string, prefix: string) => Promise<Board>;
  updateBoard: (id: string, data: Partial<Board>) => Promise<void>;
  deleteBoard: (id: string) => Promise<void>;
  toggleBoardStar: (id: string) => Promise<void>;
  suggestPrefix: (name: string) => Promise<string>;
  checkPrefix: (prefix: string) => Promise<boolean>;

  // Status operations
  createStatus: (
    boardId: string,
    data: { name: string; color: string },
  ) => Promise<BoardStatus>;
  updateStatus: (
    id: string,
    data: Partial<Pick<BoardStatus, "name" | "color">>,
  ) => Promise<void>;
  deleteStatus: (id: string, boardId: string) => Promise<void>;
  reorderStatuses: (boardId: string, statusIds: string[]) => Promise<void>;

  // Task operations
  fetchTasks: (boardId: string) => Promise<void>;
  createTask: (boardId: string, data: Partial<Task>) => Promise<Task>;
  updateTask: (id: string, data: Partial<Task>) => Promise<void>;
  deleteTask: (id: string) => Promise<void>;
  toggleTaskStar: (id: string) => Promise<void>;
  reorderTask: (
    taskId: string,
    newStatusId: string,
    newIndex: number,
  ) => Promise<void>;

  // Child task operations
  fetchChildTasks: (parentId: string) => Promise<void>;
  createChildTask: (parentId: string, data: Partial<Task>) => Promise<Task>;
  updateChildTask: (id: string, parentId: string, data: Partial<Task>) => Promise<void>;
  deleteChildTask: (id: string, parentId: string) => Promise<void>;
}

export const useBoardStore = create<BoardState>((set, get) => ({
  boards: [],
  tasks: {},
  childTasks: {},
  isLoading: false,
  hasMore: true,
  afterCursor: null,

  // Board operations
  fetchBoards: async (loadMore = false) => {
    const { afterCursor, isLoading } = get();

    if (isLoading || (loadMore && !afterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && afterCursor) {
        params.after = afterCursor;
      }

      const response = await api.get<PaginatedResponse<Board>>(
        "/boards",
        params,
      );

      set((state) => ({
        boards: loadMore ? [...state.boards, ...response.data] : response.data,
        afterCursor: response.metadata.after,
        hasMore: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch boards:", error);
      set({ boards: [], isLoading: false, hasMore: false });
    }
  },

  createBoard: async (name: string, prefix: string) => {
    const board = await api.post<Board>("/boards", { name, prefix });
    set((state) => ({
      boards: [...(Array.isArray(state.boards) ? state.boards : []), board],
    }));
    return board;
  },

  updateBoard: async (id: string, data: Partial<Board>) => {
    const board = await api.patch<Board>(`/boards/${id}`, data);
    set((state) => ({
      boards: state.boards.map((b) => (b.id === id ? board : b)),
    }));
  },

  deleteBoard: async (id: string) => {
    await api.delete(`/boards/${id}`);
    set((state) => ({
      boards: state.boards.filter((b) => b.id !== id),
      tasks: { ...state.tasks, [id]: [] },
    }));
  },

  toggleBoardStar: async (id: string) => {
    const board = get().boards.find((b) => b.id === id);
    if (board) {
      set((state) => ({
        boards: state.boards.map((b) =>
          b.id === id ? { ...b, starred: !b.starred } : b,
        ),
      }));
      await api.post("/stars/toggle", { type: "board", id });
    }
  },

  suggestPrefix: async (name: string) => {
    const res = await api.get<{ prefix: string }>("/boards/suggest-prefix", {
      name,
    });
    return res.prefix;
  },

  checkPrefix: async (prefix: string) => {
    const res = await api.get<{ available: boolean }>("/boards/check-prefix", {
      prefix,
    });
    return res.available;
  },

  // Status operations
  createStatus: async (
    boardId: string,
    data: { name: string; color: string },
  ) => {
    const status = await api.post<BoardStatus>(
      `/boards/${boardId}/statuses`,
      data,
    );
    set((state) => ({
      boards: state.boards.map((b) =>
        b.id === boardId
          ? {
              ...b,
              statuses: insertStatusKeepingDoneLast(b.statuses, status),
            }
          : b,
      ),
    }));
    return status;
  },

  updateStatus: async (
    id: string,
    data: Partial<Pick<BoardStatus, "name" | "color">>,
  ) => {
    const status = await api.patch<BoardStatus>(`/statuses/${id}`, data);
    set((state) => ({
      boards: state.boards.map((b) => ({
        ...b,
        statuses: b.statuses?.map((s) => (s.id === id ? status : s)),
      })),
    }));
  },

  deleteStatus: async (id: string, boardId: string) => {
    await api.delete(`/statuses/${id}`);
    set((state) => ({
      boards: state.boards.map((b) =>
        b.id === boardId
          ? { ...b, statuses: b.statuses?.filter((s) => s.id !== id) }
          : b,
      ),
    }));
    // Refetch tasks since some may have been moved to a different status
    await get().fetchTasks(boardId);
  },

  reorderStatuses: async (boardId: string, statusIds: string[]) => {
    await api.put(`/boards/${boardId}/statuses/reorder`, {
      status_ids: statusIds,
    });
    // Update local state with new positions
    set((state) => ({
      boards: state.boards.map((b) => {
        if (b.id !== boardId || !b.statuses) return b;
        const reorderedStatuses = statusIds
          .map((id, index) => {
            const status = b.statuses!.find((s) => s.id === id);
            return status ? { ...status, position: index } : null;
          })
          .filter((s): s is BoardStatus => s !== null);
        return { ...b, statuses: reorderedStatuses };
      }),
    }));
  },

  // Task operations
  fetchTasks: async (boardId: string) => {
    try {
      const response = await api.get<PaginatedResponse<Task>>(
        `/tasks?board_id=${boardId}`,
      );
      set((state) => ({
        tasks: { ...state.tasks, [boardId]: response.data },
      }));
    } catch (error) {
      console.error("Failed to fetch tasks:", error);
    }
  },

  createTask: async (boardId: string, data: Partial<Task>) => {
    const task = await api.post<Task>(`/tasks`, { ...data, boardId });
    set((state) => ({
      tasks: {
        ...state.tasks,
        [boardId]: [
          ...(Array.isArray(state.tasks[boardId]) ? state.tasks[boardId] : []),
          task,
        ],
      },
    }));
    return task;
  },

  updateTask: async (id: string, data: Partial<Task>) => {
    const state = get();

    // Find the old task to check if status changed
    let oldTask: Task | undefined;
    for (const tasks of Object.values(state.tasks)) {
      const found = tasks.find((t) => t.id === id);
      if (found) {
        oldTask = found;
        break;
      }
    }

    const task = await api.patch<Task>(`/tasks/${id}`, data);

    // Celebrate if task was just completed (status changed to done)
    if (task.status?.isDone && oldTask && !oldTask.status?.isDone) {
      celebrateTaskCompletion();
    }

    set((state) => {
      const boardId = task.boardId;
      const existingTasks = Array.isArray(state.tasks[boardId])
        ? state.tasks[boardId]
        : [];
      return {
        tasks: {
          ...state.tasks,
          [boardId]: existingTasks.map((t) => (t.id === id ? task : t)),
        },
      };
    });
  },

  toggleTaskStar: async (id: string) => {
    // Optimistically toggle in all boards
    set((state) => {
      const newTasks = { ...state.tasks };
      for (const boardId of Object.keys(newTasks)) {
        newTasks[boardId] = newTasks[boardId].map((t) =>
          t.id === id ? { ...t, starred: !t.starred } : t,
        );
      }
      // Also toggle in child tasks
      const newChildTasks = { ...state.childTasks };
      for (const parentId of Object.keys(newChildTasks)) {
        newChildTasks[parentId] = newChildTasks[parentId].map((t) =>
          t.id === id ? { ...t, starred: !t.starred } : t,
        );
      }
      return { tasks: newTasks, childTasks: newChildTasks };
    });
    await api.post("/stars/toggle", { type: "task", id });
  },

  deleteTask: async (id: string) => {
    await api.delete(`/tasks/${id}`);
    set((state) => {
      const newTasks = { ...state.tasks };
      Object.keys(newTasks).forEach((boardId) => {
        if (Array.isArray(newTasks[boardId])) {
          newTasks[boardId] = newTasks[boardId].filter((t) => t.id !== id);
        }
      });
      return { tasks: newTasks };
    });
  },

  reorderTask: async (
    taskId: string,
    newStatusId: string,
    newIndex: number,
  ) => {
    const state = get();

    // Find the task and its board
    let task: Task | undefined;
    let boardId: string | undefined;
    let board: Board | undefined;

    for (const [bid, tasks] of Object.entries(state.tasks)) {
      const found = tasks.find((t) => t.id === taskId);
      if (found) {
        task = found;
        boardId = bid;
        board = state.boards.find((b) => b.id === bid);
        break;
      }
    }

    if (!task || !boardId) return;

    // Check if moving to a DONE status (for celebration)
    const oldStatusIsDone = task.status?.isDone;
    const newStatus = board?.statuses?.find((s) => s.id === newStatusId);
    const newStatusIsDone = newStatus?.isDone;

    const boardTasks = state.tasks[boardId] || [];

    // Optimistic update: reorder tasks locally
    // 1. Remove task from its current position
    const tasksWithoutMoved = boardTasks.filter((t) => t.id !== taskId);

    // 2. Get tasks in the target status, sorted by position
    const targetStatusTasks = tasksWithoutMoved
      .filter((t) => t.statusId === newStatusId)
      .sort((a, b) => a.position - b.position);

    // 3. Insert the moved task at the new index
    const movedTask = { ...task, statusId: newStatusId };

    // 4. Calculate new positions for the target status
    const updatedTargetTasks = [
      ...targetStatusTasks.slice(0, newIndex),
      movedTask,
      ...targetStatusTasks.slice(newIndex),
    ].map((t, idx) => ({ ...t, position: idx }));

    // 5. Combine with tasks from other statuses
    const otherTasks = tasksWithoutMoved.filter(
      (t) => t.statusId !== newStatusId,
    );
    const updatedTasks = [...otherTasks, ...updatedTargetTasks];

    set((state) => ({
      tasks: { ...state.tasks, [boardId!]: updatedTasks },
    }));

    try {
      // Call the API
      await api.put(`/tasks/${taskId}/reorder`, {
        position: newIndex,
        status_id: newStatusId,
      });

      // Celebrate if task was just completed (moved to done status)
      if (newStatusIsDone && !oldStatusIsDone) {
        celebrateTaskCompletion();
      }

      // Refetch to get accurate positions from server
      await get().fetchTasks(boardId);
    } catch (error) {
      console.error("Failed to reorder task:", error);
      // Revert on error by refetching
      await get().fetchTasks(boardId);
    }
  },

  // Child task operations
  fetchChildTasks: async (parentId: string) => {
    try {
      const response = await api.get<Task[]>(
        `/tasks?parent_id=${parentId}`,
      );
      const tasks = Array.isArray(response) ? response : [];
      set((state) => ({
        childTasks: { ...state.childTasks, [parentId]: tasks },
      }));
    } catch (error) {
      console.error("Failed to fetch child tasks:", error);
      set((state) => ({
        childTasks: { ...state.childTasks, [parentId]: [] },
      }));
    }
  },

  createChildTask: async (parentId: string, data: Partial<Task>) => {
    const task = await api.post<Task>(`/tasks`, { ...data, parentId });
    set((state) => {
      const existing = Array.isArray(state.childTasks[parentId])
        ? state.childTasks[parentId]
        : [];
      const updatedChildren = [...existing, task];
      const totalCount = updatedChildren.length;
      const doneCount = updatedChildren.filter((c) => c.isCompleted).length;

      const updateParentCounts = (t: Task) =>
        t.id === parentId
          ? { ...t, childCount: totalCount, childDoneCount: doneCount }
          : t;

      const newTasks = { ...state.tasks };
      Object.keys(newTasks).forEach((boardId) => {
        if (Array.isArray(newTasks[boardId])) {
          newTasks[boardId] = newTasks[boardId].map(updateParentCounts);
        }
      });

      return {
        childTasks: { ...state.childTasks, [parentId]: updatedChildren },
        tasks: newTasks,
      };
    });
    return task;
  },

  updateChildTask: async (id: string, parentId: string, data: Partial<Task>) => {
    const task = await api.patch<Task>(`/tasks/${id}`, data);
    set((state) => {
      const existing = Array.isArray(state.childTasks[parentId])
        ? state.childTasks[parentId]
        : [];
      const updatedChildren = existing.map((c) => (c.id === id ? task : c));
      const doneCount = updatedChildren.filter((c) => c.isCompleted).length;

      const updateParentCounts = (t: Task) =>
        t.id === parentId ? { ...t, childDoneCount: doneCount } : t;

      const newTasks = { ...state.tasks };
      Object.keys(newTasks).forEach((boardId) => {
        if (Array.isArray(newTasks[boardId])) {
          newTasks[boardId] = newTasks[boardId].map(updateParentCounts);
        }
      });

      return {
        childTasks: { ...state.childTasks, [parentId]: updatedChildren },
        tasks: newTasks,
      };
    });
  },

  deleteChildTask: async (id: string, parentId: string) => {
    await api.delete(`/tasks/${id}`);
    set((state) => {
      const existing = Array.isArray(state.childTasks[parentId])
        ? state.childTasks[parentId]
        : [];
      const updatedChildren = existing.filter((c) => c.id !== id);
      const totalCount = updatedChildren.length;
      const doneCount = updatedChildren.filter((c) => c.isCompleted).length;

      const updateParentCounts = (t: Task) =>
        t.id === parentId
          ? { ...t, childCount: totalCount, childDoneCount: doneCount }
          : t;

      const newTasks = { ...state.tasks };
      Object.keys(newTasks).forEach((boardId) => {
        if (Array.isArray(newTasks[boardId])) {
          newTasks[boardId] = newTasks[boardId].map(updateParentCounts);
        }
      });

      return {
        childTasks: { ...state.childTasks, [parentId]: updatedChildren },
        tasks: newTasks,
      };
    });
  },
}));
