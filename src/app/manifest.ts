import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Pickle",
    short_name: "Pickle",
    description: "남는건 사진뿐! 가족과 함께 보는 우리 아이 사진첩",
    start_url: "/albums",
    display: "standalone",
    background_color: "#12141A",
    theme_color: "#12141A",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
