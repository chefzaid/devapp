export interface User {
  id?: number;
  name: string;
  username: string;
  email: string;
}

export type CreateUserRequest = Omit<User, 'id'>;
