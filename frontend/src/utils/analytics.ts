import apiClient from './api';

// Types for analytics data
export interface TaskAnalytics {
  totalTasks: number;
  overdueTasks: number;
  completedTasks: number;
  completionRate: number;
  avgCompletionTime: number | null;
  statusDistribution: {
    [key: string]: {
      count: number;
    }[];
  };
  priorityDistribution: {
    [key: string]: {
      count: number;
    }[];
  };
  riskDistribution: {
    [key: string]: {
      count: number;
    }[];
  };
}

export interface TaskTrends {
  dailyCompletion: {
    day: string;
    completed: number;
  }[];
  dailyCreation: {
    day: string;
    created: number;
  }[];
  delayMetrics: {
    averageDelay: number | null;
    totalDelayedTasks: number;
  };
  priorityChanges: number;
  predictionAccuracy: {
    enabled: boolean;
    message: string;
  };
}

export interface TaskFilter {
  priority?: string[];
  riskLevel?: string[];
  status?: string[];
  dueDate?: {
    start?: string;
    end?: string;
  };
  search?: string;
}

// API functions
export async function fetchDashboardSummary(): Promise<TaskAnalytics> {
  const response = await apiClient.get('/dashboard/summary/');
  return response.data;
}

export async function fetchDashboardTrends(): Promise<TaskTrends> {
  const response = await apiClient.get('/dashboard/trends/');
  return response.data;
}

export async function searchTasks(filters: TaskFilter) {
  const response = await apiClient.get('/tasks/search/', { params: filters });
  return response.data;
}