-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_album_members" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "albumId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'member',
    "joinedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "album_members_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "album_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_album_members" ("albumId", "id", "joinedAt", "role", "userId") SELECT "albumId", "id", "joinedAt", "role", "userId" FROM "album_members";
DROP TABLE "album_members";
ALTER TABLE "new_album_members" RENAME TO "album_members";
CREATE UNIQUE INDEX "album_members_albumId_userId_key" ON "album_members"("albumId", "userId");
CREATE TABLE "new_comments" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "albumId" TEXT NOT NULL,
    "dayKey" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "comments_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "comments_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_comments" ("albumId", "content", "createdAt", "dayKey", "id", "userId") SELECT "albumId", "content", "createdAt", "dayKey", "id", "userId" FROM "comments";
DROP TABLE "comments";
ALTER TABLE "new_comments" RENAME TO "comments";
CREATE INDEX "comments_albumId_dayKey_idx" ON "comments"("albumId", "dayKey");
CREATE TABLE "new_day_reactions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "albumId" TEXT NOT NULL,
    "dayKey" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "day_reactions_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "day_reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_day_reactions" ("albumId", "createdAt", "dayKey", "id", "type", "userId") SELECT "albumId", "createdAt", "dayKey", "id", "type", "userId" FROM "day_reactions";
DROP TABLE "day_reactions";
ALTER TABLE "new_day_reactions" RENAME TO "day_reactions";
CREATE UNIQUE INDEX "day_reactions_albumId_dayKey_userId_key" ON "day_reactions"("albumId", "dayKey", "userId");
CREATE TABLE "new_invites" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "token" TEXT NOT NULL,
    "albumId" TEXT NOT NULL,
    "expiresAt" DATETIME NOT NULL,
    "maxUses" INTEGER NOT NULL,
    "useCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "invites_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_invites" ("albumId", "createdAt", "expiresAt", "id", "maxUses", "token", "useCount") SELECT "albumId", "createdAt", "expiresAt", "id", "maxUses", "token", "useCount" FROM "invites";
DROP TABLE "invites";
ALTER TABLE "new_invites" RENAME TO "invites";
CREATE UNIQUE INDEX "invites_token_key" ON "invites"("token");
CREATE TABLE "new_media" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "albumId" TEXT NOT NULL,
    "uploaderId" TEXT NOT NULL,
    "originalFilename" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "bytes" BIGINT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "path" TEXT NOT NULL,
    "takenAt" DATETIME,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" DATETIME,
    CONSTRAINT "media_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "media_uploaderId_fkey" FOREIGN KEY ("uploaderId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_media" ("albumId", "bytes", "createdAt", "deletedAt", "height", "id", "mime", "originalFilename", "path", "takenAt", "uploaderId", "width") SELECT "albumId", "bytes", "createdAt", "deletedAt", "height", "id", "mime", "originalFilename", "path", "takenAt", "uploaderId", "width" FROM "media";
DROP TABLE "media";
ALTER TABLE "new_media" RENAME TO "media";
CREATE TABLE "new_media_variants" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "mediaId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "bytes" BIGINT NOT NULL,
    "path" TEXT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    CONSTRAINT "media_variants_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "media" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_media_variants" ("bytes", "height", "id", "kind", "mediaId", "path", "width") SELECT "bytes", "height", "id", "kind", "mediaId", "path", "width" FROM "media_variants";
DROP TABLE "media_variants";
ALTER TABLE "new_media_variants" RENAME TO "media_variants";
CREATE TABLE "new_reactions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "mediaId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "reactions_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "media" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_reactions" ("createdAt", "id", "mediaId", "type", "userId") SELECT "createdAt", "id", "mediaId", "type", "userId" FROM "reactions";
DROP TABLE "reactions";
ALTER TABLE "new_reactions" RENAME TO "reactions";
CREATE UNIQUE INDEX "reactions_mediaId_userId_key" ON "reactions"("mediaId", "userId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
