export const API_URL = import.meta.env.VITE_API_URL || "/api";

interface RequestOptions extends RequestInit {
  params?: Record<string, string>;
}

// Helper to convert snake_case to camelCase
function toCamelCase(str: string): string {
  return str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
}

// Helper to convert camelCase to snake_case
function toSnakeCase(str: string): string {
  return str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
}

// Recursively convert object keys from snake_case to camelCase
function convertKeysToCamelCase(obj: any): any {
  if (Array.isArray(obj)) {
    return obj.map(convertKeysToCamelCase);
  } else if (obj !== null && typeof obj === "object") {
    return Object.keys(obj).reduce((acc, key) => {
      const camelKey = toCamelCase(key);
      acc[camelKey] = convertKeysToCamelCase(obj[key]);
      return acc;
    }, {} as any);
  }
  return obj;
}

// Recursively convert object keys from camelCase to snake_case
function convertKeysToSnakeCase(obj: any): any {
  if (Array.isArray(obj)) {
    return obj.map(convertKeysToSnakeCase);
  } else if (obj !== null && typeof obj === "object") {
    return Object.keys(obj).reduce((acc, key) => {
      const snakeKey = toSnakeCase(key);
      acc[snakeKey] = convertKeysToSnakeCase(obj[key]);
      return acc;
    }, {} as any);
  }
  return obj;
}

function extractFirstErrorMessage(errors: unknown): string | null {
  if (!errors || typeof errors !== "object") {
    return null;
  }

  const errorEntries = Object.values(errors as Record<string, unknown>);
  for (const errorEntry of errorEntries) {
    if (typeof errorEntry === "string") {
      return errorEntry;
    }

    if (Array.isArray(errorEntry)) {
      const firstString = errorEntry.find((item) => typeof item === "string");
      if (typeof firstString === "string") {
        return firstString;
      }
    }
  }

  return null;
}

class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    this.token = localStorage.getItem("auth_token");
  }

  setToken(token: string) {
    this.token = token;
    localStorage.setItem("auth_token", token);
  }

  clearToken() {
    this.token = null;
    localStorage.removeItem("auth_token");
  }

  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
    };
    if (this.token) {
      headers["Authorization"] = `Bearer ${this.token}`;
    }
    return headers;
  }

  private buildUrl(path: string, params?: Record<string, string>): string {
    let url = `${this.baseUrl}${path}`;

    if (params) {
      const searchParams = new URLSearchParams(params);
      url += `?${searchParams.toString()}`;
    }

    return url;
  }

  async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const { params, ...init } = options;
    const url = this.buildUrl(path, params);

    const response = await fetch(url, {
      ...init,
      credentials: "include", // Always include cookies for session-based auth
      headers: {
        ...this.getHeaders(),
        ...init.headers,
      },
    });

    if (!response.ok) {
      const error = await response
        .json()
        .catch(() => ({ message: "Request failed" }));
      const convertedError = convertKeysToCamelCase(error);
      const fallbackMessage = `HTTP ${response.status}`;

      const message =
        (typeof convertedError?.message === "string" && convertedError.message) ||
        (typeof convertedError?.error === "string" && convertedError.error) ||
        extractFirstErrorMessage(convertedError?.errors) ||
        fallbackMessage;

      throw new Error(message);
    }

    // Handle 204 No Content responses (e.g., from DELETE)
    if (response.status === 204) {
      return {} as T;
    }

    const data = await response.json();

    // Convert snake_case keys to camelCase
    const converted = convertKeysToCamelCase(data);

    // Return full response if it has metadata (paginated), otherwise just data
    return (converted.metadata ? converted : converted.data || converted) as T;
  }

  get<T>(path: string, params?: Record<string, string>): Promise<T> {
    return this.request<T>(path, { method: "GET", params });
  }

  post<T>(path: string, data?: unknown): Promise<T> {
    return this.request<T>(path, {
      method: "POST",
      body: JSON.stringify(convertKeysToSnakeCase(data)),
    });
  }

  put<T>(path: string, data?: unknown): Promise<T> {
    return this.request<T>(path, {
      method: "PUT",
      body: JSON.stringify(convertKeysToSnakeCase(data)),
    });
  }

  patch<T>(path: string, data?: unknown): Promise<T> {
    return this.request<T>(path, {
      method: "PATCH",
      body: JSON.stringify(convertKeysToSnakeCase(data)),
    });
  }

  delete<T>(path: string): Promise<T> {
    return this.request<T>(path, { method: "DELETE" });
  }
}

export const api = new ApiClient(API_URL);
