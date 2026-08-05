import { PrismaClient } from "@prisma/client";

// Media byte counts are stored as BigInt (sqlite INTEGER). JSON.stringify()
// throws on BigInt by default, so give it a safe numeric serialization —
// values here stay well under Number.MAX_SAFE_INTEGER (petabyte range).
declare global {
  interface BigInt {
    toJSON(): number;
  }
}
if (!(BigInt.prototype as unknown as { toJSON?: unknown }).toJSON) {
  (BigInt.prototype as unknown as { toJSON: () => number }).toJSON = function (this: bigint) {
    return Number(this);
  };
}

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
