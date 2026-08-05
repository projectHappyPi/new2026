"use client";

import { useEffect, useState } from "react";

export default function StorageBanner() {
  const [state, setState] = useState<{ show: boolean; level?: string; message?: string }>({ show: false });

  useEffect(() => {
    let cancelled = false;
    async function check() {
      try {
        const res = await fetch("/api/storage/banner");
        const data = await res.json();
        if (!cancelled) setState(data);
      } catch {
        /* ignore */
      }
    }
    check();
    const interval = setInterval(check, 60_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  if (!state.show) return null;

  return (
    <div
      className={`px-4 py-2 text-center text-sm font-medium text-white ${
        state.level === "block" ? "bg-red-600" : "bg-orange-500"
      }`}
    >
      {state.message}
    </div>
  );
}
