'use client';
import ReactConfetti from 'react-confetti';
import { useState, useEffect } from 'react';

interface ConfettiEffectProps {
  width?: number;
  height?: number;
  style?: React.CSSProperties;
}

const ConfettiEffect = ({ width, height, style }: ConfettiEffectProps) => {
  const [windowSize, setWindowSize] = useState({ width: 0, height: 0 });

  useEffect(() => {
    if (width && height) return; // Don't listen to window if custom size is provided
    const handleResize = () => {
      setWindowSize({ width: window.innerWidth, height: window.innerHeight });
    };
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [width, height]);

  const confettiWidth = width || windowSize.width;
  const confettiHeight = height || windowSize.height;

  if (!confettiWidth || !confettiHeight) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        top: 0,
        width: confettiWidth,
        height: confettiHeight,
        pointerEvents: 'none',
        ...style,
      }}
    >
      <ReactConfetti
        width={confettiWidth}
        height={confettiHeight}
        recycle={false}
        numberOfPieces={300}
        gravity={0.2}
        initialVelocityY={20}
      />
    </div>
  );
};

export default ConfettiEffect;
