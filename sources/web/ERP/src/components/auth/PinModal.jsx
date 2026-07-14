import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Delete } from 'lucide-react';

export default function PinModal({ isOpen, onClose, onPinComplete, user }) {
  const [pin, setPin] = useState('');

  // Auto-submit when length reaches 4
  useEffect(() => {
    if (pin.length === 4) {
      const timeout = setTimeout(() => {
        onPinComplete(pin);
        setPin('');
      }, 300);
      return () => clearTimeout(timeout);
    }
  }, [pin, onPinComplete]);

  // Keyboard support — digits, Backspace, Enter
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e) => {
      // Digit keys: top row (0–9) and numpad (Numpad0–Numpad9)
      if (/^[0-9]$/.test(e.key) || (e.code && e.code.startsWith('Numpad') && /^[0-9]$/.test(e.key))) {
        setPin(prev => prev.length < 4 ? prev + e.key : prev);
      } else if (e.key === 'Backspace') {
        setPin(prev => prev.slice(0, -1));
      } else if (e.key === 'Enter') {
        setPin(prev => {
          if (prev.length > 0) {
            onPinComplete(prev);
            return '';
          }
          return prev;
        });
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onPinComplete]);

  // Handle number click
  const handleNumberClick = (num) => {
    if (pin.length < 4) {
      setPin(prev => prev + num);
    }
  };

  const handleBackspace = () => {
    setPin(prev => prev.slice(0, -1));
  };

  const handleSubmit = (e) => {
    e?.preventDefault();
    if (pin.length > 0) {
      onPinComplete(pin);
      setPin(''); // Reset after submit
    }
  };

  const handleClose = () => {
    setPin('');
    onClose();
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            className="bg-white rounded-3xl shadow-xl w-full max-w-sm overflow-hidden flex flex-col"
          >
            <div className="flex justify-between items-center p-4 border-b border-slate-100">
              <h3 className="text-lg font-semibold text-slate-800">Enter Passcode</h3>
              <button 
                onClick={handleClose}
                className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <div className="p-6 flex flex-col items-center">
              <div className="mb-4">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold text-white ${user?.colorClass || 'bg-primary-600'}`}>
                  {user?.initials || '?'}
                </div>
              </div>
              <p className="text-slate-600 mb-6 text-center">
                Enter passcode for <span className="font-semibold text-slate-800">{user?.name}</span>
              </p>

              {/* PIN Display */}
              <div className="flex space-x-4 mb-8">
                {[...Array(4)].map((_, i) => (
                  <div 
                    key={i}
                    className={`w-4 h-4 rounded-full transition-colors ${
                      i < pin.length ? 'bg-primary-600' : 'bg-slate-200'
                    }`}
                  />
                ))}
              </div>

              {/* Keypad */}
              <div className="grid grid-cols-3 gap-4 w-full max-w-[240px]">
                {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) => (
                  <button
                    key={num}
                    onClick={() => handleNumberClick(num.toString())}
                    className="w-16 h-16 rounded-full flex items-center justify-center text-2xl font-medium text-slate-700 bg-slate-50 hover:bg-slate-100 active:bg-slate-200 transition-colors"
                  >
                    {num}
                  </button>
                ))}
                
                {/* Empty cell */}
                <div />
                
                <button
                  onClick={() => handleNumberClick('0')}
                  className="w-16 h-16 rounded-full flex items-center justify-center text-2xl font-medium text-slate-700 bg-slate-50 hover:bg-slate-100 active:bg-slate-200 transition-colors"
                >
                  0
                </button>
                
                <button
                  onClick={handleBackspace}
                  className="w-16 h-16 rounded-full flex items-center justify-center text-slate-600 hover:text-slate-800 hover:bg-slate-100 active:bg-slate-200 transition-colors"
                >
                  <Delete className="w-6 h-6" />
                </button>
              </div>

              <button
                onClick={handleSubmit}
                disabled={pin.length === 0}
                className="mt-8 w-full btn-primary py-3 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Login
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
