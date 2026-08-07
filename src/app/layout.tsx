import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import NavBar from "@/components/NavBar";
import StorageBanner from "@/components/StorageBanner";
import SplashScreen from "@/components/SplashScreen";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Pickle",
  description: "남는건 사진뿐! 가족과 함께 보는 우리 아이 사진첩",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Pickle" },
  icons: { apple: "/icons/apple-touch-icon.png" },
};

export const viewport: Viewport = {
  themeColor: "#12141A",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="ko"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-zinc-50 dark:bg-black dark:text-zinc-50">
        <SplashScreen />
        <NavBar />
        <StorageBanner />
        <main className="flex-1">{children}</main>
      </body>
    </html>
  );
}
