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
