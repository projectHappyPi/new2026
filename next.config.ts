import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // ffmpeg-static resolves its binary path via __dirname at require-time; bundling it breaks that
  // path resolution, so keep it (and sharp, for the same reason) as a real Node require instead.
  serverExternalPackages: ["ffmpeg-static", "sharp"],
};

export default nextConfig;
