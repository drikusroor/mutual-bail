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
