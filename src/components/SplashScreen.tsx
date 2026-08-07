"use client";

import { useEffect, useState } from "react";

const SESSION_KEY = "pickle_splash_shown";

export default function SplashScreen() {
  const [visible, setVisible] = useState(false);
  const [fading, setFading] = useState(false);

  useEffect(() => {
    if (sessionStorage.getItem(SESSION_KEY)) return;
    sessionStorage.setItem(SESSION_KEY, "1");
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time mount check against sessionStorage, not derived from props/state
    setVisible(true);
  }, []);

  useEffect(() => {
    if (!visible) return;
    const maxWait = setTimeout(dismiss, 3500);
    return () => clearTimeout(maxWait);
  }, [visible]);

  function dismiss() {
    setFading(true);
    setTimeout(() => setVisible(false), 300);
  }

  if (!visible) return null;

  return (
    <div
      className={`fixed inset-0 z-50 flex items-center justify-center bg-black transition-opacity duration-300 ${fading ? "opacity-0" : "opacity-100"}`}
      onClick={dismiss}
    >
      <video className="h-full w-full object-cover" src="/branding/pickle-splash.mp4" autoPlay muted playsInline onEnded={dismiss} />
      <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-end gap-2 bg-gradient-to-t from-black/80 via-black/0 to-black/0 pb-16">
        <span className="text-2xl font-extrabold tracking-tight text-white">Pickle</span>
      </div>
    </div>
  );
}
