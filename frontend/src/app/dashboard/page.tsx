'use client';

import { TaskList } from '@/components/tasks/TaskList';
import { TaskTrendsChart } from '@/components/tasks/TaskTrendsChart';
import { SearchFilterPanel } from '@/components/tasks/SearchFilterPanel';
import { withAuth } from '@/utils/withAuth';
import { useState, useEffect } from 'react';
import { fetchDashboardSummary, TaskAnalytics, TaskFilter, searchTasks } from '@/utils/analytics';

function DashboardPage() {
  const [selectedView, setSelectedView] = useState('overview');
  const [analyticsData, setAnalyticsData] = useState<TaskAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filteredTasks, setFilteredTasks] = useState<any[]>([]); // TODO: Replace any with proper Task type

  const fetchData = async () => {
    try {
      const data = await fetchDashboardSummary();
      setAnalyticsData(data);
      setError(null);
    } catch (err) {
      setError('Failed to load dashboard data');
      console.error('Error fetching dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // Poll for updates every 2 minutes
    const interval = setInterval(fetchData, 2 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  const handleFilterChange = async (filters: TaskFilter) => {
    try {
      const results = await searchTasks(filters);
      setFilteredTasks(results);
    } catch (err) {
      console.error('Error applying filters:', err);
    }
  };

  const renderContent = () => {
    if (loading) {
      return (
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-cyan-400">Loading dashboard data...</div>
        </div>
      );
    }

    if (error) {
      return (
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-red-400">{error}</div>
        </div>
      );
    }

    switch (selectedView) {
      case 'overview':
        return (
          <>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
              <div className="bg-gray-800 p-6 rounded-lg border border-cyan-500/30 shadow-lg hover:shadow-cyan-500/10 transition-all hover:-translate-y-1">
                <h3 className="text-lg font-semibold mb-2 text-cyan-400">Total Tasks</h3>
                <div className="text-3xl font-bold">{analyticsData?.totalTasks || 0}</div>
                <div className="text-sm text-gray-400 mt-2">Active projects</div>
              </div>

              <div className="bg-gray-800 p-6 rounded-lg border border-green-500/30 shadow-lg hover:shadow-green-500/10 transition-all hover:-translate-y-1">
                <h3 className="text-lg font-semibold mb-2 text-green-400">Completed</h3>
                <div className="text-3xl font-bold">{analyticsData?.completedTasks || 0}</div>
                <div className="text-sm text-gray-400 mt-2">Tasks finished</div>
              </div>

              <div className="bg-gray-800 p-6 rounded-lg border border-red-500/30 shadow-lg hover:shadow-red-500/10 transition-all hover:-translate-y-1">
                <h3 className="text-lg font-semibold mb-2 text-red-400">Overdue</h3>
                <div className="text-3xl font-bold">{analyticsData?.overdueTasks || 0}</div>
                <div className="text-sm text-gray-400 mt-2">Require attention</div>
              </div>
            </div>

            <div className="mb-8">
              <TaskTrendsChart />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
                <div className="flex justify-between items-center mb-4">
                  <h2 className="text-xl font-bold text-cyan-400">Recent Tasks</h2>
                  <button className="text-sm text-cyan-400 hover:text-cyan-300 transition-colors">
                    View All →
                  </button>
                </div>
                <TaskList limit={5} />
              </div>

              <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
                <h2 className="text-xl font-bold mb-6 text-cyan-400">Task Priority Distribution</h2>
                <div className="space-y-6">
                  {(['high', 'medium', 'low'] as const).map((priority) => (
                    <div key={priority} className="space-y-2">
                      <div className="flex items-center justify-between">
                        <div className={`text-${priority === 'high' ? 'red' : priority === 'medium' ? 'yellow' : 'green'}-400`}>
                          {priority.charAt(0).toUpperCase() + priority.slice(1)} Priority
                        </div>
                        <div className="text-gray-400">
                          {analyticsData?.tasksByPriority[priority] || 0} tasks
                        </div>
                      </div>
                      <div className="flex-1 bg-gray-700 rounded-full h-2">
                        <div 
                          className={`bg-gradient-to-r from-${priority === 'high' ? 'red' : priority === 'medium' ? 'yellow' : 'green'}-600 
                            to-${priority === 'high' ? 'red' : priority === 'medium' ? 'yellow' : 'green'}-400 rounded-full h-2 transition-all duration-500`}
                          style={{ width: `${analyticsData ? (analyticsData.tasksByPriority[priority] / analyticsData.totalTasks) * 100 : 0}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        );

      case 'analytics':
        return (
          <div className="space-y-6">
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
              <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
                <h2 className="text-xl font-bold mb-6 text-cyan-400">Risk Level Distribution</h2>
                <div className="space-y-4">
                  {Object.entries(analyticsData?.riskDistribution || {}).map(([risk, count]) => (
                    <div key={risk} className="flex items-center space-x-4">
                      <div className="w-32 text-gray-400">{risk}</div>
                      <div className="flex-1 bg-gray-700 rounded-full h-2">
                        <div
                          className="bg-cyan-500 rounded-full h-2 transition-all duration-500"
                          style={{ width: `${analyticsData ? (count / analyticsData.totalTasks) * 100 : 0}%` }}
                        />
                      </div>
                      <div className="w-16 text-right text-gray-400">{count}</div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
                <h2 className="text-xl font-bold mb-6 text-cyan-400">Status Distribution</h2>
                <div className="space-y-4">
                  {Object.entries(analyticsData?.statusDistribution || {}).map(([status, count]) => (
                    <div key={status} className="flex items-center space-x-4">
                      <div className="w-32 text-gray-400">{status.replace('_', ' ')}</div>
                      <div className="flex-1 bg-gray-700 rounded-full h-2">
                        <div
                          className="bg-cyan-500 rounded-full h-2 transition-all duration-500"
                          style={{ width: `${analyticsData ? (count / analyticsData.totalTasks) * 100 : 0}%` }}
                        />
                      </div>
                      <div className="w-16 text-right text-gray-400">{count}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <TaskTrendsChart />
          </div>
        );

      case 'insights':
        return (
          <div className="space-y-6">
            <SearchFilterPanel onFilterChange={handleFilterChange} />
            
            <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
              <h2 className="text-xl font-bold mb-6 text-cyan-400">Filtered Results</h2>
              <TaskList tasks={filteredTasks} limit={10} />
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Navigation Sidebar */}
      <div className="fixed left-0 top-0 h-full w-64 bg-gray-800 p-6 border-r border-gray-700">
        <h2 className="text-xl font-bold mb-8 text-cyan-400">Dashboard Views</h2>
        <nav className="space-y-4">
          {['overview', 'analytics', 'insights'].map((view) => (
            <button 
              key={view}
              onClick={() => setSelectedView(view)}
              className={`w-full text-left px-4 py-2 rounded transition-colors ${
                selectedView === view ? 'bg-cyan-500 text-white' : 'text-gray-300 hover:bg-gray-700'
              }`}
            >
              {view.charAt(0).toUpperCase() + view.slice(1)}
            </button>
          ))}
        </nav>

        {/* Quick Stats Section */}
        {analyticsData && (
          <div className="mt-12 p-4 bg-gray-900/50 rounded-lg border border-gray-700">
            <h3 className="text-sm font-semibold text-gray-400 mb-3">QUICK STATS</h3>
            <div className="space-y-2">
              <div className="text-xs text-gray-500">Completion Rate</div>
              <div className="text-lg font-bold text-cyan-400">
                {Math.round((analyticsData.completedTasks / analyticsData.totalTasks) * 100)}%
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Main Content */}
      <div className="ml-64 p-8">
        <header className="mb-8 bg-gray-800/50 p-6 rounded-lg border border-gray-700">
          <h1 className="text-4xl font-bold text-cyan-400 mb-2 tracking-tight">TASK INTELLIGENCE DASHBOARD</h1>
          <p className="text-gray-400">Real-time analytics and insights for your task management</p>
        </header>

        {renderContent()}
      </div>
    </div>
  );
}

export default withAuth(DashboardPage);