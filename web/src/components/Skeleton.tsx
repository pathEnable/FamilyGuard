import React from "react";

export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={`animate-pulse bg-gray-200/60 rounded-md ${className}`}
    />
  );
}

export function CardSkeleton() {
  return (
    <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50">
      <div className="flex gap-4 mb-6">
        <Skeleton className="w-12 h-12 rounded-xl" />
        <div className="space-y-2">
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-4 w-48" />
        </div>
      </div>
      <Skeleton className="h-24 w-full rounded-xl" />
    </div>
  );
}
