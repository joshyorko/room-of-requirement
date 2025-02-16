'use client';
import { TaskList } from '@/components/tasks/TaskList';
import { withAuth } from '@/utils/withAuth';

function DashboardPage() {
  return (
    <div>
      <h1 className="text-2xl font-bold mb-6 text-gray-900">Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-4 text-gray-900">Recent Tasks</h2>
          <TaskList limit={5} />
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-4 text-gray-900">Task Statistics</h2>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-gray-900 font-medium">Total Tasks</span>
              <span className="text-gray-900 font-semibold">0</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-900 font-medium">Completed Tasks</span>
              <span className="text-gray-900 font-semibold">0</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default withAuth(DashboardPage);