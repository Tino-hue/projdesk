import { useState, useEffect } from 'react';

const STEPS = [
  {
    title: 'Welcome to ProjDesk',
    body: 'Declare a business object once. See it projected into 4 targets simultaneously.',
    icon: '1',
  },
  {
    title: 'Edit fields & constraints',
    body: 'The left panel is your model editor. Change any value and watch the right panels update live.',
    icon: '2',
  },
  {
    title: 'Honest projection',
    body: 'What a target cannot carry is shown as "dropped + reason". Never silently discarded.',
    icon: '3',
  },
];

export function Onboarding() {
  const [step, setStep] = useState(0);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    try {
      const seen = localStorage.getItem('projdesk_onboarded');
      if (!seen) setVisible(true);
    } catch { setVisible(true); }
  }, []);

  const close = () => {
    setVisible(false);
    try { localStorage.setItem('projdesk_onboarded', '1'); } catch { /* ignore */ }
  };

  if (!visible) return null;

  return (
    <div className="onboarding-overlay" onClick={close}>
      <div className="onboarding-card" onClick={(e) => e.stopPropagation()}>
        <div className="text-xs text-slate-400 mb-2">
          Step {step + 1} of {STEPS.length}
        </div>
        <div className="w-12 h-12 rounded-full bg-blue-500 text-white flex items-center justify-center text-xl font-bold mb-4">
          {STEPS[step].icon}
        </div>
        <h2 className="text-lg font-bold mb-2">{STEPS[step].title}</h2>
        <p className="text-sm text-slate-500 dark:text-slate-400 mb-6 leading-relaxed">
          {STEPS[step].body}
        </p>
        <div className="flex items-center justify-between">
          <button
            className="text-xs text-slate-400 hover:text-slate-600"
            onClick={close}
          >
            Skip
          </button>
          <div className="flex gap-2">
            {step > 0 && (
              <button
                className="px-3 py-1.5 text-xs bg-slate-100 dark:bg-slate-700 rounded hover:bg-slate-200"
                onClick={() => setStep(step - 1)}
              >
                Back
              </button>
            )}
            {step < STEPS.length - 1 ? (
              <button
                className="px-4 py-1.5 text-xs bg-blue-500 text-white rounded hover:bg-blue-600"
                onClick={() => setStep(step + 1)}
              >
                Next
              </button>
            ) : (
              <button
                className="px-4 py-1.5 text-xs bg-emerald-500 text-white rounded hover:bg-emerald-600"
                onClick={close}
              >
                Get Started
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

