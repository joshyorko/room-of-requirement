import Image from "next/image";

export default function Home() {
  return (
    <div className="max-w-4xl mx-auto text-center">
      <h1 className="text-4xl font-bold tracking-tight sm:text-6xl mb-6">
        Manage Your Tasks Effectively
      </h1>
      <p className="text-lg leading-8 text-gray-600 mb-8">
        A modern task management solution for individuals and teams.
        Stay organized, meet deadlines, and achieve your goals.
      </p>
      <div className="flex justify-center gap-4">
        <a href="/login" className="rounded-md bg-indigo-600 px-6 py-3 text-white hover:bg-indigo-500">
          Get Started
        </a>
        <a href="/dashboard" className="rounded-md bg-gray-100 px-6 py-3 text-gray-900 hover:bg-gray-200">
          View Demo
        </a>
      </div>
    </div>
  );
}
