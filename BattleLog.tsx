import { useEffect, useRef } from 'react';

interface BattleLogProps {
  messages: string[];
}

export const BattleLog = ({ messages }: BattleLogProps) => {
  const logRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (logRef.current) {
      logRef.current.scrollTop = logRef.current.scrollHeight;
    }
  }, [messages]);

  return (
    <div className="pokemon-card h-32 p-4 overflow-hidden">
      <div 
        ref={logRef}
        className="h-full overflow-y-auto space-y-2 scrollbar-thin scrollbar-thumb-primary/20"
      >
        {messages.length === 0 ? (
          <p className="text-muted-foreground text-center">Battle is about to begin...</p>
        ) : (
          messages.map((message, index) => (
            <p 
              key={index} 
              className="text-sm animate-fade-in text-shadow"
            >
              {message}
            </p>
          ))
        )}
      </div>
    </div>
  );
};