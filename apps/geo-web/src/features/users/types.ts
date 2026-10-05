export type Role = "superuser" | "supervisor" | "editor" | "viewer";
export type Status = "active" | "inactive";
export type AuthSource = "local" | "azure";

export interface AdminUser {
  id: string;
  email: string;
  display_name: string;
  role: Role;
  status: Status;
  auth_source: AuthSource;
  pending: boolean;
  last_login_at?: string;
  created_at: string;
  is_break_glass: boolean;
}

export interface UsersListResponse {
  users: AdminUser[];
  total: number;
}

export interface UpdateUserRequest {
  display_name?: string;
  role?: Role;
  status?: Status;
}

export interface LoginEvent {
  id: string;
  created_at: string;
  ip_address: string;
  email: string;
  user_id?: string;
  display_name?: string;
  role?: Role;
}

export interface LoginHistoryResponse {
  events: LoginEvent[];
  total: number;
}
