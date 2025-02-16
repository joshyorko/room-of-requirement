export interface Task {
  id: number;
  title: string;
  status: 'pending' | 'completed';
  dueDate: string;
}