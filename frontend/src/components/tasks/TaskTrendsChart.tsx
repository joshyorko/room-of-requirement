import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
  ChartOptions
} from 'chart.js';
import { useEffect, useState } from 'react';
import { fetchDashboardTrends, TaskTrends } from '@/utils/analytics';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

const chartOptions: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'top',
      labels: {
        color: '#e5e7eb',
      }
    },
    tooltip: {
      mode: 'index' as const,
      intersect: false,
      backgroundColor: 'rgba(17, 24, 39, 0.8)',
      titleColor: '#fff',
      bodyColor: '#e5e7eb',
      borderColor: 'rgba(6, 182, 212, 0.2)',
      borderWidth: 1,
    },
  },
  scales: {
    x: {
      grid: {
        color: 'rgba(75, 85, 99, 0.2)',
      },
      ticks: {
        color: '#e5e7eb',
      }
    },
    y: {
      grid: {
        color: 'rgba(75, 85, 99, 0.2)',
      },
      ticks: {
        color: '#e5e7eb',
      }
    }
  },
  interaction: {
    mode: 'x',
    intersect: false
  }
};

export function TaskTrendsChart() {
  const [trendsData, setTrendsData] = useState<TaskTrends | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const data = await fetchDashboardTrends();
      setTrendsData(data);
      setError(null);
    } catch (err) {
      setError('Failed to load trend data');
      console.error('Error fetching trends:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // Poll for updates every 5 minutes
    const interval = setInterval(fetchData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="w-full h-[400px] bg-gray-800 p-6 rounded-lg border border-gray-700 flex items-center justify-center">
        <div className="text-cyan-400">Loading trends data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="w-full h-[400px] bg-gray-800 p-6 rounded-lg border border-gray-700 flex items-center justify-center">
        <div className="text-red-400">{error}</div>
      </div>
    );
  }

  const chartData = trendsData ? {
    labels: trendsData.dailyCreation.map(item => new Date(item.day).toLocaleDateString()),
    datasets: [
      {
        label: 'Tasks Created',
        data: trendsData.dailyCreation.map(item => item.created),
        borderColor: 'rgb(6, 182, 212)',
        backgroundColor: 'rgba(6, 182, 212, 0.1)',
        fill: true,
        tension: 0.4,
      },
      {
        label: 'Tasks Completed',
        data: trendsData.dailyCompletion.map(item => item.completed),
        borderColor: 'rgb(34, 197, 94)',
        backgroundColor: 'rgba(34, 197, 94, 0.1)',
        fill: true,
        tension: 0.4,
      }
    ]
  } : { labels: [], datasets: [] };

  return (
    <div className="w-full h-[400px] bg-gray-800 p-6 rounded-lg border border-gray-700">
      <h2 className="text-xl font-bold mb-4 text-cyan-400">Task Activity Trends</h2>
      <div className="h-[300px]">
        <Line options={chartOptions} data={chartData} />
      </div>
      {trendsData && (
        <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
          <div className="text-gray-400">
            Average Delay: {trendsData.delayMetrics.averageDelay ? 
              `${Math.round(trendsData.delayMetrics.averageDelay / 86400)} days` : 
              'N/A'}
          </div>
          <div className="text-gray-400">
            Delayed Tasks: {trendsData.delayMetrics.totalDelayedTasks}
          </div>
        </div>
      )}
    </div>
  );
}