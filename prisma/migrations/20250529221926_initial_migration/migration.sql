-- CreateTable
CREATE TABLE "BailEvent" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "description" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "numRequired" INTEGER NOT NULL
);

-- CreateTable
CREATE TABLE "Participant" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "secret" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "wantsToBail" BOOLEAN NOT NULL DEFAULT false,
    "bailEventId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Participant_bailEventId_fkey" FOREIGN KEY ("bailEventId") REFERENCES "BailEvent" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "Participant_secret_key" ON "Participant"("secret");

-- CreateIndex
CREATE INDEX "Participant_bailEventId_idx" ON "Participant"("bailEventId");
