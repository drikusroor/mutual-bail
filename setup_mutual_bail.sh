#!/bin/bash

echo "MutualBail Project Setup Script"
echo "---------------------------------"
echo "This script will create files, install dependencies, and set up Prisma."
echo "Ensure you are in the root directory of your Next.js project."
read -p "Do you want to continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Setup aborted."
    exit 1
fi

# --- 1. Create Directories ---
echo "Creating directories..."
mkdir -p app/api/create-bail
mkdir -p app/api/bail-request
mkdir -p app/api/event-status/[eventId]/[participantSecret]
mkdir -p app/bail/[eventId]/[participantSecret]
mkdir -p components
mkdir -p lib
mkdir -p prisma

# --- 2. Install bun Dependencies ---
echo "Installing bun dependencies..."
bun install uuid react-confetti @prisma/client
bun install -D prisma @types/uuid

# --- 3. Tailwind CSS and Global Styles ---
echo "Setting up Tailwind CSS and global styles..."

# tailwind.config.js
cat <<EOF > tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      }
    },
  },
  plugins: [],
};
EOF

# postcss.config.js (usually default is fine, but ensure it exists for Tailwind)
if [ ! -f postcss.config.js ]; then
cat <<EOF > postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
fi

# app/globals.css
cat <<EOF > app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# --- 4. Prisma Setup ---
echo "Setting up Prisma..."

# Initialize Prisma
bunx prisma init --datasource-provider sqlite

# prisma/schema.prisma
cat <<EOF > prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model BailEvent {
  id            String        @id @default(uuid())
  description   String?
  status        String        @default("active") // "active" or "cancelled"
  createdAt     DateTime      @default(now())
  participants  Participant[]
  numRequired   Int           // Total number of participants for this event
}

model Participant {
  id            String     @id @default(uuid())
  secret        String     @unique // This is the participant's unique link secret
  name          String
  wantsToBail   Boolean    @default(false)
  bailEventId   String
  bailEvent     BailEvent  @relation(fields: [bailEventId], references: [id], onDelete: Cascade)
  createdAt     DateTime   @default(now())

  @@index([bailEventId])
}
EOF

# lib/prisma.ts
cat <<EOF > lib/prisma.ts
import { PrismaClient } from '@prisma/client';

declare global {
  // allow global \`var\` declarations
  // eslint-disable-next-line no-unused-vars
  var prisma: PrismaClient | undefined;
}

const prisma =
  global.prisma ||
  new PrismaClient({
    // log: ['query', 'info', 'warn', 'error'], // Uncomment for debugging
  });

if (process.env.NODE_ENV !== 'production') global.prisma = prisma;

export default prisma;
EOF

# --- 5. Run Prisma Migrations ---
echo "Generating Prisma client and running migrations..."
bunx prisma generate
bunx prisma migrate dev --name init_bail_tables

# --- 6. API Route Files ---
echo "Creating API route files..."

# app/api/create-bail/route.ts
cat <<EOF > app/api/create-bail/route.ts
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { v4 as uuidv4 } from 'uuid';

export async function POST(request: Request) {
  try {
    const { description, numParticipants = 2 } = await request.json();

    if (numParticipants < 2 || numParticipants > 5) {
      return NextResponse.json({ message: 'Number of participants must be between 2 and 5.' }, { status: 400 });
    }

    const participantSecrets: { name: string, secret: string }[] = [];
    for (let i = 0; i < numParticipants; i++) {
      participantSecrets.push({
        secret: uuidv4(),
        name: \`Participant \${i + 1}\`,
      });
    }

    const newEvent = await prisma.bailEvent.create({
      data: {
        description: description || 'A secret plan',
        status: 'active',
        numRequired: numParticipants,
        participants: {
          create: participantSecrets.map(p => ({
            secret: p.secret,
            name: p.name,
            wantsToBail: false,
          })),
        },
      },
      include: {
        participants: true,
      },
    });

    const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000';
    const participantLinks = newEvent.participants.map(p => ({
      name: p.name,
      secret: p.secret,
      link: \`\${baseUrl}/bail/\${newEvent.id}/\${p.secret}\`,
    }));

    return NextResponse.json({ eventId: newEvent.id, participantLinks }, { status: 201 });
  } catch (error) {
    console.error('Error creating bail event:', error);
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
EOF

# app/api/event-status/[eventId]/[participantSecret]/route.ts
cat <<EOF > app/api/event-status/[eventId]/[participantSecret]/route.ts
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';

export async function GET(
  request: Request,
  { params }: { params: { eventId: string; participantSecret: string } }
) {
  try {
    const { eventId, participantSecret } = params;
    if (!eventId || !participantSecret) {
      return NextResponse.json({ message: 'Event ID and Participant Secret are required.' }, { status: 400 });
    }

    const eventData = await prisma.bailEvent.findUnique({
      where: { id: eventId },
      include: {
        participants: {
          select: {
            name: true,
            wantsToBail: true,
            secret: true,
          }
        }
      },
    });

    if (!eventData) {
      return NextResponse.json({ message: 'Bailout plan not found or expired.' }, { status: 404 });
    }
    
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    if (eventData.createdAt < sevenDaysAgo) {
        return NextResponse.json({ message: 'Bailout plan has expired.' }, { status: 404 });
    }

    const currentParticipant = eventData.participants.find(p => p.secret === participantSecret);
    if (!currentParticipant) {
      return NextResponse.json({ message: 'Invalid participant for this event.' }, { status: 403 });
    }

    const publicEventData = {
      id: eventData.id,
      description: eventData.description,
      status: eventData.status,
      participants: eventData.participants.map(p => ({
        name: p.name,
        wantsToBail: p.wantsToBail,
        isCurrentUser: p.secret === participantSecret,
      })),
      currentUser: {
         name: currentParticipant.name,
         wantsToBail: currentParticipant.wantsToBail
      }
    };

    return NextResponse.json(publicEventData, { status: 200 });
  } catch (error) {
    console.error('Error fetching event status:', error);
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
EOF

# app/api/bail-request/route.ts
cat <<EOF > app/api/bail-request/route.ts
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { eventId, participantSecret } = await request.json();

    if (!eventId || !participantSecret) {
      return NextResponse.json({ message: 'Event ID and Participant Secret are required.' }, { status: 400 });
    }

    const resultEvent = await prisma.\$transaction(async (tx) => {
      const event = await tx.bailEvent.findUnique({
        where: { id: eventId },
        include: { participants: true },
      });

      if (!event) {
        throw new Error('Bailout plan not found or expired.');
      }

      if (event.status === 'cancelled') {
        return event;
      }

      const participantToUpdate = event.participants.find(p => p.secret === participantSecret);

      if (!participantToUpdate) {
        throw new Error('Invalid participant for this event.');
      }

      if (participantToUpdate.wantsToBail) {
        return event;
      }

      await tx.participant.update({
        where: { id: participantToUpdate.id },
        data: { wantsToBail: true },
      });

      const updatedParticipants = await tx.participant.findMany({
        where: { bailEventId: eventId }
      });

      const allBailed = updatedParticipants.every(p => p.wantsToBail);

      let finalEvent = event;
      if (allBailed) {
        finalEvent = await tx.bailEvent.update({
          where: { id: eventId },
          data: { status: 'cancelled' },
          include: { participants: true },
        });
      } else {
        finalEvent = await tx.bailEvent.findUnique({
            where: { id: eventId },
            include: { participants: true }
        });
        if (!finalEvent) throw new Error("Event disappeared post-participant update");
      }
      return finalEvent;
    });

    const currentParticipantForResponse = resultEvent.participants.find(p => p.secret === participantSecret);
    const publicEventData = {
      id: resultEvent.id,
      description: resultEvent.description,
      status: resultEvent.status,
      participants: resultEvent.participants.map(p => ({
        name: p.name,
        wantsToBail: p.wantsToBail,
        isCurrentUser: p.secret === participantSecret,
      })),
      currentUser: currentParticipantForResponse ? {
         name: currentParticipantForResponse.name,
         wantsToBail: currentParticipantForResponse.wantsToBail
      } : null
    };

    const message = resultEvent.status === 'cancelled' ? 'Plans cancelled! Everyone bailed.'
                  : publicEventData.currentUser?.wantsToBail ? 'Your bail request is registered.'
                  : 'Bail request updated.';

    return NextResponse.json({ message, event: publicEventData }, { status: 200 });

  } catch (error: any) {
    console.error('Error processing bail request:', error);
    if (error.message === 'Bailout plan not found or expired.' || error.message === 'Invalid participant for this event.') {
        return NextResponse.json({ message: error.message }, { status: 404 });
    }
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
EOF

# --- 7. Component Files ---
echo "Creating component files..."

# components/ConfettiEffect.tsx
cat <<EOF > components/ConfettiEffect.tsx
'use client';
import ReactConfetti from 'react-confetti';
import { useState, useEffect } from 'react';

const ConfettiEffect = () => {
  const [windowSize, setWindowSize] = useState({ width: 0, height: 0 });

  useEffect(() => {
    const handleResize = () => {
      setWindowSize({ width: window.innerWidth, height: window.innerHeight });
    };
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (!windowSize.width || !windowSize.height) return null;

  return (
    <ReactConfetti
      width={windowSize.width}
      height={windowSize.height}
      recycle={false}
      numberOfPieces={300}
      gravity={0.2}
      initialVelocityY={20}
    />
  );
};

export default ConfettiEffect;
EOF

# components/ShareLinks.tsx
cat <<EOF > components/ShareLinks.tsx
'use client';
import { useState } from 'react';

interface ParticipantLink {
  name: string;
  link: string;
  secret: string;
}

interface ShareLinksProps {
  participantLinks: ParticipantLink[];
  creatorSecret: string;
}

const ShareLinks: React.FC<ShareLinksProps> = ({ participantLinks, creatorSecret }) => {
  const [copiedLink, setCopiedLink] = useState<string | null>(null);

  const handleCopy = (link: string) => {
    navigator.clipboard.writeText(link).then(() => {
      setCopiedLink(link);
      setTimeout(() => setCopiedLink(null), 2000);
    });
  };

  const creatorLink = participantLinks.find(p => p.secret === creatorSecret);
  const otherLinks = participantLinks.filter(p => p.secret !== creatorSecret);

  return (
    <div className="mt-6 bg-white/10 p-6 rounded-lg w-full space-y-4">
      {creatorLink && (
        <div className="mb-4">
            <p className="font-semibold text-purple-200 mb-1">This is your personal link (don't share it):</p>
            <div className="flex items-center space-x-2">
                <input type="text" readOnly value={creatorLink.link} className="flex-grow p-2 rounded bg-purple-700/50 text-purple-100 text-sm truncate" />
                <button
                    onClick={() => handleCopy(creatorLink.link)}
                    className="px-3 py-2 bg-pink-500 hover:bg-pink-600 text-xs rounded whitespace-nowrap"
                >
                    {copiedLink === creatorLink.link ? 'Copied!' : 'Copy'}
                </button>
            </div>
        </div>
      )}

      {otherLinks.length > 0 && (
         <div>
            <p className="font-semibold text-purple-200 mb-2">Share these links with the other participants:</p>
            {otherLinks.map((pLink) => (
            <div key={pLink.secret} className="mb-2">
                <p className="text-sm text-purple-200 mb-1">{pLink.name}:</p>
                <div className="flex items-center space-x-2">
                <input type="text" readOnly value={pLink.link} className="flex-grow p-2 rounded bg-purple-700/50 text-purple-100 text-sm truncate" />
                <button
                    onClick={() => handleCopy(pLink.link)}
                    className="px-3 py-2 bg-pink-500 hover:bg-pink-600 text-xs rounded whitespace-nowrap"
                >
                    {copiedLink === pLink.link ? 'Copied!' : 'Copy Link'}
                </button>
                </div>
            </div>
            ))}
         </div>
      )}
    </div>
  );
};

export default ShareLinks;
EOF

# --- 8. Page Files ---
echo "Creating page files..."

# app/layout.tsx
cat <<EOF > app/layout.tsx
import './globals.css';
import { Nunito } from 'next/font/google';

const nunito = Nunito({ subsets: ['latin'], weight: ['400', '700', '800'] });

export const metadata = {
  title: 'MutualBail - Cancel Plans, Guilt-Free!',
  description: 'The easy way to mutually agree to cancel plans.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={\`\${nunito.className} bg-gradient-to-br from-purple-600 via-pink-500 to-orange-400 min-h-screen text-white flex flex-col items-center justify-center p-4 selection:bg-pink-300 selection:text-pink-800\`}>
        {children}
        <Analytics /> {/* Optional: remove if not using Vercel Analytics */}
      </body>
    </html>
  );
}
EOF

# app/page.tsx (Homepage)
cat <<EOF > app/page.tsx
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function HomePage() {
  const [description, setDescription] = useState('');
  const [numParticipants, setNumParticipants] = useState(2);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  const handleCreateBail = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      const res = await fetch('/api/create-bail', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ description, numParticipants }),
      });
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.message || 'Failed to create bailout plan.');
      }
      const data = await res.json();
      // Store links for the creator's view to display them on the next page
      localStorage.setItem(\`event-\${data.eventId}-links\`, JSON.stringify(data.participantLinks));
      router.push(\`/bail/\${data.eventId}/\${data.participantLinks[0].secret}?created=true\`);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <main className="bg-white/20 backdrop-blur-lg p-8 rounded-xl shadow-2xl max-w-md w-full text-center">
      <h1 className="text-5xl font-extrabold mb-2 text-transparent bg-clip-text bg-gradient-to-r from-pink-300 to-purple-300">
        MutualBail
      </h1>
      <p className="mb-6 text-purple-100">
        Want to cancel plans without the awkwardness? <br/>
        Create a MutualBail pact!
      </p>

      <form onSubmit={handleCreateBail} className="space-y-4">
        <div>
          <label htmlFor="description" className="block text-sm font-medium text-purple-200 mb-1">
            Event Description (Optional)
          </label>
          <input
            type="text"
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="e.g., 'Dinner on Friday'"
            className="w-full px-4 py-2 rounded-md bg-white/30 text-white placeholder-purple-200/70 focus:ring-2 focus:ring-pink-400 focus:outline-none"
          />
        </div>
        <div>
          <label htmlFor="numParticipants" className="block text-sm font-medium text-purple-200 mb-1">
            Number of People (2-5)
          </label>
          <select
            id="numParticipants"
            value={numParticipants}
            onChange={(e) => setNumParticipants(parseInt(e.target.value))}
            className="w-full px-4 py-2 rounded-md bg-white/30 text-white focus:ring-2 focus:ring-pink-400 focus:outline-none appearance-none"
            style={{ backgroundImage: \`url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3E%3Cpath stroke='%23D8B4FE' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3E%3C/svg%3E")\`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 0.5rem center', backgroundSize: '1.5em 1.5em'}}
          >
            {[2, 3, 4, 5].map(n => <option key={n} value={n} className="bg-purple-500">{n}</option>)}
          </select>
        </div>
        <button
          type="submit"
          disabled={isLoading}
          className="w-full bg-pink-500 hover:bg-pink-600 text-white font-bold py-3 px-4 rounded-lg transition duration-150 ease-in-out transform hover:scale-105 disabled:opacity-50 disabled:hover:scale-100"
        >
          {isLoading ? 'Creating...' : 'Create Bailout Pact'}
        </button>
        {error && <p className="text-red-300 mt-2 text-sm">{error}</p>}
      </form>
      <p className="mt-8 text-xs text-purple-200/80">
        If everyone secretly wants to bail, the plans are off!
      </p>
    </main>
  );
}
EOF

# app/bail/[eventId]/[participantSecret]/page.tsx
cat <<EOF > app/bail/[eventId]/[participantSecret]/page.tsx
'use client';
import { useEffect, useState, useCallback } from 'react';
import { useParams, useSearchParams } from 'next/navigation';
import ConfettiEffect from '@/components/ConfettiEffect';
import ShareLinks from '@/components/ShareLinks';
import Link from 'next/link';

interface PublicParticipant {
  name: string;
  wantsToBail: boolean;
  isCurrentUser: boolean;
}

interface PublicEventData {
  id: string;
  description: string | null;
  status: 'active' | 'cancelled';
  participants: PublicParticipant[];
  currentUser: { name: string, wantsToBail: boolean } | null;
}

interface ParticipantLinkForSharing {
  name: string;
  link: string;
  secret: string;
}

export default function BailPage() {
  const params = useParams();
  const searchParams = useSearchParams();

  const eventId = params.eventId as string;
  const participantSecret = params.participantSecret as string;

  const [eventData, setEventData] = useState<PublicEventData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [showConfetti, setShowConfetti] = useState(false);
  const [showShareLinksComponent, setShowShareLinksComponent] = useState(false);
  const [allParticipantLinksForSharing, setAllParticipantLinksForSharing] = useState<ParticipantLinkForSharing[]>([]);

  const fetchEventStatus = useCallback(async () => {
    if (!eventId || !participantSecret) return;
    try {
      const res = await fetch(\`/api/event-status/\${eventId}/\${participantSecret}\`);
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.message || 'Failed to fetch event status.');
      }
      const data: PublicEventData = await res.json();
      setEventData(data);
      if (data.status === 'cancelled' && !showConfetti) { // Prevent re-triggering confetti on poll
        setShowConfetti(true);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, [eventId, participantSecret, showConfetti]);

  useEffect(() => {
    fetchEventStatus();
    if (searchParams.get('created') === 'true') {
      const storedLinks = localStorage.getItem(\`event-\${eventId}-links\`);
      if (storedLinks) {
        setAllParticipantLinksForSharing(JSON.parse(storedLinks));
        setShowShareLinksComponent(true); // Show ShareLinks component
        localStorage.removeItem(\`event-\${eventId}-links\`); // Clean up
      } else {
        console.warn("Participant links not found in localStorage for ShareLinks.");
      }
    }
  }, [fetchEventStatus, eventId, searchParams]);

  useEffect(() => {
    let intervalId: NodeJS.Timeout;
    if (eventData && eventData.status === 'active') {
      intervalId = setInterval(fetchEventStatus, 7000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [eventData, fetchEventStatus]);

  const handleBailRequest = async () => {
    setActionLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/bail-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ eventId, participantSecret }),
      });
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.message || 'Failed to submit bail request.');
      }
      const data = await res.json();
      setEventData(data.event);
      if (data.event.status === 'cancelled') {
        setShowConfetti(true);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="text-center p-8">
        <div className="animate-pulse text-2xl font-semibold text-purple-200">Loading Bailout Status...</div>
      </div>
    );
  }

  if (error && !eventData) {
    return (
      <div className="bg-white/20 backdrop-blur-lg p-8 rounded-xl shadow-2xl max-w-lg w-full text-center">
        <h1 className="text-3xl font-bold text-red-300 mb-4">Oops!</h1>
        <p className="text-purple-100 mb-6">{error}</p>
        <Link href="/" className="bg-pink-500 hover:bg-pink-600 text-white font-bold py-2 px-4 rounded-lg">
            Go Home
        </Link>
      </div>
    );
  }

  if (!eventData || !eventData.currentUser) {
    return <div className="text-xl text-purple-200">Bailout plan details not found or you are not a valid participant. It might have expired.</div>;
  }

  const numWantingToBail = eventData.participants.filter(p => p.wantsToBail).length;
  const totalParticipants = eventData.participants.length;

  return (
    <div className="bg-white/20 backdrop-blur-lg p-6 md:p-8 rounded-xl shadow-2xl max-w-lg w-full text-center">
      {showConfetti && <ConfettiEffect />}
      <h1 className="text-3xl sm:text-4xl font-extrabold mb-3 text-transparent bg-clip-text bg-gradient-to-r from-pink-300 to-purple-300">
        MutualBail Pact
      </h1>
      <p className="text-lg text-purple-100 mb-1">For: <span className="font-semibold">{eventData.description || "This amazing plan"}</span></p>
      <p className="text-sm text-purple-200 mb-6">ID: <span className="opacity-70 text-xs">{eventData.id}</span></p>

      {error && <p className="text-red-300 my-3 text-sm bg-red-900/50 p-2 rounded">{error}</p>}

      {eventData.status === 'cancelled' ? (
        <div className="my-8">
          <h2 className="text-4xl font-bold text-green-300 animate-pulse-slow">PLANS CANCELLED!</h2>
          <p className="text-purple-100 mt-2">Phew! You're all off the hook.</p>
        </div>
      ) : (
        <div className="my-6">
          <p className="text-xl text-purple-100 mb-4">
            <span className="font-bold text-pink-300">{numWantingToBail}</span> out of {' '}
            <span className="font-bold text-purple-300">{totalParticipants}</span> {' '}
            participant{totalParticipants === 1 ? '' : 's'} want to bail.
          </p>

          {eventData.currentUser.wantsToBail ? (
            <p className="text-lg text-green-300 bg-green-900/30 p-3 rounded-md">
              You've requested to bail! Waiting for others...
            </p>
          ) : (
            <button
              onClick={handleBailRequest}
              disabled={actionLoading}
              className="bg-pink-500 hover:bg-pink-600 text-white font-bold py-3 px-6 rounded-lg text-lg transition duration-150 ease-in-out transform hover:scale-105 disabled:opacity-50 disabled:transform-none"
            >
              {actionLoading ? 'Submitting...' : 'I Secretly Want To Bail!'}
            </button>
          )}
          <div className="mt-6 space-y-1 text-left text-sm text-purple-200/90 max-w-xs mx-auto">
             {eventData.participants.map(p => (
                 <p key={p.name} className={\`p-2 rounded-md \${p.wantsToBail ? 'bg-green-500/20 text-green-300' : 'bg-purple-500/10'}\`}>
                     {p.name}: {p.wantsToBail ? 'Wants to bail ✅' : 'Still in... ⏳'} {p.isCurrentUser ? <span className="text-xs opacity-70">(You)</span> : ''}
                 </p>
             ))}
          </div>
        </div>
      )}

      {showShareLinksComponent && allParticipantLinksForSharing.length > 0 && (
          <ShareLinks participantLinks={allParticipantLinksForSharing} creatorSecret={participantSecret} />
      )}

      <Link href="/" className="inline-block mt-8 text-sm text-pink-200 hover:text-pink-100 underline">
        Create a new Bailout Pact
      </Link>
    </div>
  );
}
EOF

# --- 9. Environment File ---
echo "Creating .env.local file..."
cat <<EOF > .env.local
# This file is created by Prisma init, but we add NEXT_PUBLIC_BASE_URL
# DATABASE_URL is set by 'bunx prisma init'
# Example for local development (update if your port is different)
NEXT_PUBLIC_BASE_URL=http://localhost:3000

# For Vercel deployment, set NEXT_PUBLIC_BASE_URL in Vercel Project Environment Variables
# e.g., NEXT_PUBLIC_BASE_URL=https://your-app-name.vercel.app
EOF

# Append DATABASE_URL if not already set by prisma init (it should be, but just in case)
if ! grep -q "DATABASE_URL" .env; then
  echo "DATABASE_URL=\"file:./dev.db\"" >> .env
fi


echo ""
echo "--- Setup Complete! ---"
echo ""
echo "Next steps:"
echo "1. Review the .env and .env.local files and ensure NEXT_PUBLIC_BASE_URL is correct for your environment."
echo "   (For Vercel deployment, set NEXT_PUBLIC_BASE_URL in Vercel Project Environment Variables)."
echo "2. Run the development server: bun run dev"
echo ""
echo "If you encounter issues, ensure Prisma migrations ran correctly and check the console."