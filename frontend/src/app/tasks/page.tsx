'use client';
import { withAuth } from '@/utils/withAuth';
import { TaskList } from '@/components/tasks/TaskList';

function TasksPage() {
  return (
    <div className="py-6">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <h1 className="text-2xl font-semibold text-gray-900 mb-6">Tasks</h1>
        <TaskList />
      </div>
    </div>
  );
}

export default withAuth(TasksPage);