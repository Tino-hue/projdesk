import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { ThemeProvider } from './lib/theme';
import { Onboarding } from './components/Onboarding';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider>
      <Onboarding />
      <App />
    </ThemeProvider>
  </React.StrictMode>,
);
