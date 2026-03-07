import { User } from "./user.model";

export interface Order {
    id?: number;
    user: User;
    productId: number;
    status?: string;
}