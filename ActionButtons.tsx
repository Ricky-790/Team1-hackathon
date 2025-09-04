import { Zap, Shield, Package, RotateCcw } from 'lucide-react';

interface ActionButtonsProps {
  onAttack: () => void;
  onDefend: () => void;
  onItems: () => void;
  onRun: () => void;
  disabled?: boolean;
}

export const ActionButtons = ({ 
  onAttack, 
  onDefend, 
  onItems, 
  onRun,
  disabled = false 
}: ActionButtonsProps) => {
  const actions = [
    { 
      label: 'Attack', 
      icon: Zap, 
      onClick: onAttack, 
      className: 'text-primary border-primary hover:bg-primary/10' 
    },
    { 
      label: 'Defend', 
      icon: Shield, 
      onClick: onDefend, 
      className: 'text-secondary border-secondary hover:bg-secondary/10' 
    },
    { 
      label: 'Items', 
      icon: Package, 
      onClick: onItems, 
      className: 'text-accent border-accent hover:bg-accent/10' 
    },
    { 
      label: 'Run', 
      icon: RotateCcw, 
      onClick: onRun, 
      className: 'text-muted-foreground border-muted hover:bg-muted/20' 
    }
  ];

  return (
    <div className="grid grid-cols-2 gap-4 max-w-md mx-auto">
      {actions.map(({ label, icon: Icon, onClick, className }) => (
        <button
          key={label}
          onClick={onClick}
          disabled={disabled}
          className={`action-button ${className} disabled:opacity-50 disabled:cursor-not-allowed`}
        >
          <Icon className="w-5 h-5 mr-2" />
          {label}
        </button>
      ))}
    </div>
  );
};