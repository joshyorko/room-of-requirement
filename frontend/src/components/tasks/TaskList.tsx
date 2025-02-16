"use client";

import { Task } from './types';
import { TaskItem } from '@/components/tasks/TaskItem';

export interface TaskListProps {
  tasks?: Task[];
  limit?: number;
}

export function TaskList({ tasks: propTasks, limit }: TaskListProps) {
  const defaultTasks: Task[] = [
    { id: 1, title: 'Example Task 1', status: 'pending' as const, dueDate: '2024-02-01' },
    { id: 2, title: 'Example Task 2', status: 'completed' as const, dueDate: '2024-02-02' },
  ];

  const tasks = propTasks ? propTasks.slice(0, limit) : defaultTasks.slice(0, limit);

  if (tasks.length === 0) {
    return (
      <div className="text-center py-6 text-gray-400">
        No tasks found
      </div>
    );
  }

  return (
    <div className="divide-y divide-gray-700">
      {tasks.map((task) => (
        <TaskItem key={task.id} task={task} />
      ))}
    </div>
  );
}