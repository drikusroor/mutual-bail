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
      const res = await fetch(`/api/event-status/${eventId}/${participantSecret}`);
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
      const storedLinks = localStorage.getItem(`event-${eventId}-links`);
      if (storedLinks) {
        setAllParticipantLinksForSharing(JSON.parse(storedLinks));
        setShowShareLinksComponent(true); // Show ShareLinks component
        localStorage.removeItem(`event-${eventId}-links`); // Clean up
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
          {eventData.currentUser.wantsToBail ? (
            <>
              <p className="text-xl text-purple-100 mb-4">
                <span className="font-bold text-pink-300">{numWantingToBail}</span> out of {' '}
                <span className="font-bold text-purple-300">{totalParticipants}</span> {' '}
                participant{totalParticipants === 1 ? '' : 's'} want to bail.
              </p>
              <p className="text-lg text-green-300 bg-green-900/30 p-3 rounded-md">
                You've requested to bail! Waiting for others...
              </p>
            </>
          ) : (
            <>
              <button
                onClick={handleBailRequest}
                disabled={actionLoading}
                className="bg-pink-500 hover:bg-pink-600 text-white font-bold py-3 px-6 rounded-lg text-lg transition duration-150 ease-in-out transform hover:scale-105 disabled:opacity-50 disabled:transform-none"
              >
                {actionLoading ? 'Submitting...' : 'I Secretly Want To Bail!'}
              </button>
              <div className="mt-6 text-purple-200/90 text-center text-sm">
                Status hidden until you decide.
              </div>
            </>
          )}
          <div className="mt-6 space-y-1 text-left text-sm text-purple-200/90 max-w-xs mx-auto">
             {eventData.participants.map(p => (
                 <p key={p.name} className={`p-2 rounded-md ${eventData.currentUser.wantsToBail ? (p.wantsToBail ? 'bg-green-500/20 text-green-300' : 'bg-purple-500/10') : 'bg-purple-500/10'}`}>
                     {p.name}: {eventData.currentUser.wantsToBail
                       ? (p.wantsToBail ? 'Wants to bail ✅' : 'Still in... ⏳')
                       : 'Status hidden until you decide'} {p.isCurrentUser ? <span className="text-xs opacity-70">(You)</span> : ''}
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
