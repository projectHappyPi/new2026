-- CreateTable
CREATE TABLE "day_reactions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "albumId" TEXT NOT NULL,
    "dayKey" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "day_reactions_albumId_fkey" FOREIGN KEY ("albumId") REFERENCES "albums" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "day_reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_users" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "email" TEXT,
    "passwordHash" TEXT,
    "kakaoId" TEXT,
    "nickname" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'member',
    "onboarded" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO "new_users" ("createdAt", "email", "id", "kakaoId", "nickname", "passwordHash", "role") SELECT "createdAt", "email", "id", "kakaoId", "nickname", "passwordHash", "role" FROM "users";
DROP TABLE "users";
ALTER TABLE "new_users" RENAME TO "users";
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "users_kakaoId_key" ON "users"("kakaoId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE UNIQUE INDEX "day_reactions_albumId_dayKey_userId_key" ON "day_reactions"("albumId", "dayKey", "userId");
