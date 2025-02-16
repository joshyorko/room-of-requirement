import axios from 'axios';

const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add request interceptor for authentication if needed
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Token ${token}`;  // Changed from Bearer to Token
  }
  return config;
});

export default apiClient;

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

export const api = {
  register: async (data: any) => {
    const response = await fetch(`${API_BASE_URL}/register/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Registration failed');
    }
    
    return response.json();
  },

  login: async (credentials: { username: string; password: string }) => {
    const response = await fetch(`${API_BASE_URL}/api-token-auth/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(credentials),
    });

    if (!response.ok) {
      throw new Error('Invalid credentials');
    }

    return response.json();
  },

  getCurrentUser: async (token: string) => {
    const response = await fetch(`${API_BASE_URL}/users/me/`, {
      headers: {
        'Authorization': `Token ${token}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to fetch user data');
    }

    return response.json();
  },
};