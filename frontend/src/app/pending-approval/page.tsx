'use client';
import { useAuth } from '../contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export default function PendingApprovalPage() {
  const { user, token } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!token) {
      router.push('/login');
    } else if (user?.is_approved) {
      router.push('/dashboard');
    }
  }, [user, token, router]);

  return (
    <div className="min-h-full flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div className="text-center">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Account Pending Approval</h2>
            <div className="text-gray-600 space-y-4">
              <p>
                Your account is currently pending approval from an administrator.
              </p>
              <p>
                You will be able to access the full features of the application once your account is approved.
              </p>
              <p className="text-sm">
                Please check back later or contact support if you have any questions.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}