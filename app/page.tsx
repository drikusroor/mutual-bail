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
      localStorage.setItem(`event-${data.eventId}-links`, JSON.stringify(data.participantLinks));
      router.push(`/bail/${data.eventId}/${data.participantLinks[0].secret}?created=true`);
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
            style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3E%3Cpath stroke='%23D8B4FE' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 0.5rem center', backgroundSize: '1.5em 1.5em'}}
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
