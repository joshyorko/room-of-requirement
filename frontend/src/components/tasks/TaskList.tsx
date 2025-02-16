"use client";

import { Task } from './types';
import { TaskItem } from '@/components/tasks/TaskItem';

interface TaskListProps {
  limit?: number;
}

export function TaskList({ limit }: TaskListProps) {
  const tasks: Task[] = [
    { id: 1, title: 'Example Task 1', status: 'pending' as const, dueDate: '2024-02-01' },
    { id: 2, title: 'Example Task 2', status: 'completed' as const, dueDate: '2024-02-02' },
  ].slice(0, limit);

  if (tasks.length === 0) {
    return (
      <div className="text-center py-6 text-gray-900 font-medium">
        No tasks found
      </div>
    );
  }

  return (
    <div className="divide-y divide-gray-200">
      {tasks.map((task) => (
        <TaskItem key={task.id} task={task} />
      ))}
    </div>
  );
}