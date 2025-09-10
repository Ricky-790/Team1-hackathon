import { useState } from 'react';

interface PokemonCardProps {
  name: string;
  level: number;
  hp: number;
  maxHp: number;
  type: string;
  image: string;
  isPlayer?: boolean;
  isShaking?: boolean;
}

export const PokemonCard = ({ 
  name, 
  level, 
  hp, 
  maxHp, 
  type, 
  image, 
  isPlayer = false,
  isShaking = false 
}: PokemonCardProps) => {
  const hpPercentage = (hp / maxHp) * 100;
  
  const getHealthColor = () => {
    if (hpPercentage > 60) return 'health-full';
    if (hpPercentage > 25) return 'health-half';
    return 'health-low';
  };

  return (
    <div className={`pokemon-card w-full max-w-sm ${isShaking ? 'battle-effect' : ''}`}>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-xl font-bold text-shadow">{name}</h3>
          <p className="text-sm text-muted-foreground">Lv. {level}</p>
        </div>
        <div className={`px-3 py-1 rounded-full text-xs font-semibold ${
          type === 'Electric' ? 'bg-accent text-accent-foreground' :
          type === 'Fire' ? 'bg-destructive text-destructive-foreground' :
          'bg-secondary text-secondary-foreground'
        }`}>
          {type}
        </div>
      </div>
      
      <div className="mb-4">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm font-medium">HP</span>
          <span className="text-sm font-mono">{hp}/{maxHp}</span>
        </div>
        <div className="health-bar">
          <div 
            className={`health-fill ${getHealthColor()}`}
            style={{ width: `${hpPercentage}%` }}
          />
        </div>
      </div>
      
      <div className="relative h-32 rounded-lg overflow-hidden bg-gradient-to-br from-muted/20 to-muted/5">
        <img 
          src={image} 
          alt={name}
          className={`w-full h-full object-cover transition-all duration-300 ${
            isPlayer ? 'scale-x-[-1]' : ''
          }`}
        />
        <div className="absolute inset-0 bg-gradient-to-t from-background/30 to-transparent" />
      </div>
    </div>
  );
};