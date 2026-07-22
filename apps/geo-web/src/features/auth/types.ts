export interface User {
  id: string;
  email: string;
  display_name: string;
  role: "superuser" | "supervisor" | "editor" | "viewer";
}
