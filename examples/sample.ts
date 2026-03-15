import { readFileSync } from "fs";
import path from "path";

// This is a comment that should stay in place

interface UserConfig {
  name: string;
  email: string;
  age?: number;
}

const MAX_RETRIES = 3;

type Status = "active" | "inactive" | "pending";

function greet(name: string): string {
  return `Hello, ${name}!`;
}

class UserService {
  private users: UserConfig[] = [];

  addUser(user: UserConfig): void {
    this.users.push(user);
  }

  getUsers(): UserConfig[] {
    return this.users;
  }
}

const processData = (data: string[]): string[] => {
  return data.filter((item) => item.length > 0);
};

export function formatUser(user: UserConfig): string {
  return `${user.name} <${user.email}>`;
}

export const DEFAULT_CONFIG: UserConfig = {
  name: "Anonymous",
  email: "anon@example.com",
};

enum Direction {
  Up = "UP",
  Down = "DOWN",
  Left = "LEFT",
  Right = "RIGHT",
}

function calculateTotal(items: number[]): number {
  return items.reduce((sum, item) => sum + item, 0);
}
