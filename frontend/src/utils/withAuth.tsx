'use client';
import { useAuth } from '@/app/contexts/AuthContext';
import { useRouter, usePathname } from 'next/navigation';
import { useEffect } from 'react';
import { ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

export function withAuth(Component: React.ComponentType) {
  return function ProtectedRoute({ ...props }) {
    const { user, token, isLoading } = useAuth();
    const router = useRouter();
    const pathname = usePathname();

    useEffect(() => {
      if (!isLoading && !token) {
        router.push(`/login?redirect=${encodeURIComponent(pathname)}`);
      } else if (!isLoading && user && !user.is_approved && pathname !== '/pending-approval') {
        router.push('/pending-approval');
      }
    }, [isLoading, token, user, router, pathname]);

    // Show nothing while checking auth status
    if (isLoading) {
      return null;
    }

    // If not authenticated, don't render component
    if (!token) {
      return null;
    }

    // If not approved and not on pending page, don't render component
    if (!user?.is_approved && pathname !== '/pending-approval') {
      return null;
    }

    // Render component if all checks pass
    return <Component {...props} />;
  };
}