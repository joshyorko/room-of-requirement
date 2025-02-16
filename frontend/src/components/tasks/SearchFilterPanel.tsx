import { useState } from 'react';
import { TaskFilter } from '@/utils/analytics';

interface SearchFilterProps {
  onFilterChange: (filters: TaskFilter) => void;
}

export function SearchFilterPanel({ onFilterChange }: SearchFilterProps) {
  const [filters, setFilters] = useState<TaskFilter>({
    priority: [],
    riskLevel: [],
    status: [],
    search: '',
  });

  const handleFilterChange = (key: keyof TaskFilter, value: any) => {
    const newFilters = { ...filters, [key]: value };
    setFilters(newFilters);
    onFilterChange(newFilters);
  };

  const priorities = ['HIGH', 'MEDIUM', 'LOW'];
  const riskLevels = ['HIGH', 'MEDIUM', 'LOW'];
  const statuses = ['TODO', 'IN_PROGRESS', 'DONE'];

  return (
    <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
      <div className="space-y-6">
        {/* Search Bar */}
        <div>
          <label htmlFor="search" className="block text-sm font-medium text-gray-400 mb-2">
            Search Tasks
          </label>
          <input
            type="text"
            id="search"
            placeholder="Search by title or notes..."
            className="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-cyan-500"
            value={filters.search}
            onChange={(e) => handleFilterChange('search', e.target.value)}
          />
        </div>

        {/* Priority Filter */}
        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Priority</label>
          <div className="flex flex-wrap gap-2">
            {priorities.map((priority) => (
              <button
                key={priority}
                onClick={() => {
                  const newPriorities = filters.priority?.includes(priority)
                    ? filters.priority.filter(p => p !== priority)
                    : [...(filters.priority || []), priority];
                  handleFilterChange('priority', newPriorities);
                }}
                className={`px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                  filters.priority?.includes(priority)
                    ? 'bg-cyan-500 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {priority}
              </button>
            ))}
          </div>
        </div>

        {/* Risk Level Filter */}
        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Risk Level</label>
          <div className="flex flex-wrap gap-2">
            {riskLevels.map((risk) => (
              <button
                key={risk}
                onClick={() => {
                  const newRisks = filters.riskLevel?.includes(risk)
                    ? filters.riskLevel.filter(r => r !== risk)
                    : [...(filters.riskLevel || []), risk];
                  handleFilterChange('riskLevel', newRisks);
                }}
                className={`px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                  filters.riskLevel?.includes(risk)
                    ? 'bg-cyan-500 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {risk}
              </button>
            ))}
          </div>
        </div>

        {/* Status Filter */}
        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Status</label>
          <div className="flex flex-wrap gap-2">
            {statuses.map((status) => (
              <button
                key={status}
                onClick={() => {
                  const newStatuses = filters.status?.includes(status)
                    ? filters.status.filter(s => s !== status)
                    : [...(filters.status || []), status];
                  handleFilterChange('status', newStatuses);
                }}
                className={`px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                  filters.status?.includes(status)
                    ? 'bg-cyan-500 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {status.replace('_', ' ')}
              </button>
            ))}
          </div>
        </div>

        {/* Date Range */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label htmlFor="startDate" className="block text-sm font-medium text-gray-400 mb-2">
              Start Date
            </label>
            <input
              type="date"
              id="startDate"
              className="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-cyan-500"
              onChange={(e) => handleFilterChange('dueDate', { 
                ...filters.dueDate,
                start: e.target.value 
              })}
            />
          </div>
          <div>
            <label htmlFor="endDate" className="block text-sm font-medium text-gray-400 mb-2">
              End Date
            </label>
            <input
              type="date"
              id="endDate"
              className="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-cyan-500"
              onChange={(e) => handleFilterChange('dueDate', { 
                ...filters.dueDate,
                end: e.target.value 
              })}
            />
          </div>
        </div>
      </div>
    </div>
  );
}