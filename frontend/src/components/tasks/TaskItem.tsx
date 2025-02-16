'use client';

import { Task } from './types';

interface TaskItemProps {
  task: Task;
  onStatusChange?: (id: number, status: 'pending' | 'completed') => Promise<void>;
}

export function TaskItem({ task, onStatusChange }: TaskItemProps) {
  return (
    <div className="py-4 flex items-center justify-between">
      <div className="flex items-center">
        <input
          type="checkbox"
          checked={task.status === 'completed'}
          className="h-4 w-4 text-indigo-600 rounded border-gray-300 focus:ring-indigo-500"
          onChange={() => onStatusChange?.(task.id, task.status === 'completed' ? 'pending' : 'completed')}
        />
        <span className={`ml-3 text-gray-900 font-medium ${task.status === 'completed' ? 'line-through text-gray-500' : ''}`}>
          {task.title}
        </span>
      </div>
      <div className="text-sm text-gray-900 font-medium">
        Due: {new Date(task.dueDate).toLocaleDateString()}
      </div>
    </div>
  );
}