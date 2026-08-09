import fs from "node:fs";
import path from "node:path";

const COVER_PATH = path.join(process.cwd(), "public", "static", "share-cover.png");

/**
 * The Kakao share template needs a public, non-photo image (SPEC 3.6: "아기 사진이 아닌
 * 앱 로고·일러스트를 사용한다"). Generated on boot instead of committed as a binary asset
 * so operators can drop in their own public/static/share-cover.png without a code change.
 */
export async function ensureShareCoverImage() {
  if (fs.existsSync(COVER_PATH)) return;

  fs.mkdirSync(path.dirname(COVER_PATH), { recursive: true });
  const { default: sharp } = await import("sharp");

  const svg = `
    <svg width="800" height="400" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#FEE500"/>
      <circle cx="400" cy="150" r="70" fill="#3C1E1E"/>
      <text x="50%" y="300" font-size="56" font-family="sans-serif" font-weight="bold" fill="#3C1E1E" text-anchor="middle">Pickle</text>
    </svg>
  `;

  await sharp(Buffer.from(svg)).png().toFile(COVER_PATH);
}
