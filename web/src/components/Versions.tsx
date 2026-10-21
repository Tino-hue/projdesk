import { useState } from 'react';
import type { ModelInput } from '../lib/types';

interface Snapshot {
  label: string;
  data: string;
  timestamp: number;
}

interface Props {
  model: ModelInput;
  onRestore: (model: ModelInput) => void;
}

export function VersionSnapshots({ model, onRestore }: Props) {
  const [snapshots, setSnapshots] = useState<Snapshot[]>(() => {
    try {
      return JSON.parse(localStorage.getItem('projdesk_snapshots') || '[]');
    } catch { return []; }
  });
  const [name, setName] = useState('');

  const save = () => {
    const label = name || `v${snapshots.length + 1} ${new Date().toLocaleTimeString()}`;
    const entry: Snapshot = { label, data: JSON.stringify(model), timestamp: Date.now() };
    const next = [...snapshots, entry].slice(-20);
    setSnapshots(next);
    localStorage.setItem('projdesk_snapshots', JSON.stringify(next));
    setName('');
  };

  const restore = (s: Snapshot) => {
    try {
      onRestore(JSON.parse(s.data));
    } catch { /* ignore */ }
  };

  const remove = (idx: number) => {
    const next = snapshots.filter((_, i) => i !== idx);
    setSnapshots(next);
    localStorage.setItem('projdesk_snapshots', JSON.stringify(next));
  };

  return (
    <details className="mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-500 dark:text-slate-400 select-none font-medium">
        Version Snapshots ({snapshots.length})
      </summary>
      <div className="mt-2 space-y-2">
        <div className="flex gap-1">
          <input
            type="text"
            className="flex-1 px-2 py-1 border border-slate-300 dark:border-slate-600 rounded text-xs bg-white dark:bg-slate-800 dark:text-slate-200"
            placeholder="Snapshot name (optional)"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <button className="px-2 py-1 text-xs bg-blue-500 text-white rounded hover:bg-blue-600" onClick={save}>Save</button>
        </div>
        {snapshots.length > 0 && (
          <div className="space-y-1 max-h-[120px] overflow-y-auto">
            {snapshots.map((s, i) => (
              <div key={i} className="flex items-center justify-between px-2 py-1 bg-slate-50 dark:bg-slate-800 rounded">
                <div>
                  <div className="font-medium">{s.label}</div>
                  <div className="text-[10px] text-slate-400">{new Date(s.timestamp).toLocaleString()}</div>
                </div>
                <div className="flex gap-1">
                  <button className="text-blue-500 hover:underline" onClick={() => restore(s)}>Restore</button>
                  <button className="text-red-400 hover:underline" onClick={() => remove(i)}>X</button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </details>
  );
}

// ---------- Template library ----------

const TEMPLATES = [
  {
    name: 'E-Commerce Product',
    model: {
      name: 'Product', doc: 'e-commerce product', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'SKU', default: null, check: { unique: true } },
        { name: 'title', kind: 'Text', required: true, nullable: false, doc: 'product title', default: null, check: { shortest: 1, longest: 200 } },
        { name: 'price', kind: 'Real', required: true, nullable: false, doc: 'price in cents', default: null, check: { least: 0 } },
        { name: 'category', kind: 'Text', required: true, nullable: false, doc: 'category', default: null, check: { options: ['electronics', 'clothing', 'food', 'other'] } },
        { name: 'inStock', kind: 'Bool', required: true, nullable: false, doc: 'availability', default: true, check: {} },
        { name: 'tags', kind: { list: 'Text' }, required: false, nullable: false, doc: 'tags', default: null, check: { distinct: true, longest: 10 } },
      ],
    },
  },
  {
    name: 'Blog Post',
    model: {
      name: 'Post', doc: 'blog post', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'post ID', default: null, check: { unique: true } },
        { name: 'title', kind: 'Text', required: true, nullable: false, doc: 'post title', default: null, check: { shortest: 1, longest: 300 } },
        { name: 'slug', kind: 'Text', required: true, nullable: false, doc: 'URL slug', default: null, check: { pattern: '^[a-z0-9-]+$', longest: 100 } },
        { name: 'body', kind: 'Text', required: true, nullable: false, doc: 'post content', default: null, check: {} },
        { name: 'published', kind: 'Bool', required: true, nullable: false, doc: 'is published', default: false, check: {} },
        { name: 'publishedAt', kind: 'Stamp', required: false, nullable: true, doc: 'publish time', default: null, check: {} },
      ],
    },
  },
  {
    name: 'Payment Transaction',
    model: {
      name: 'Payment', doc: 'payment transaction', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'transaction ID', default: null, check: { unique: true } },
        { name: 'amount', kind: 'Real', required: true, nullable: false, doc: 'amount in cents', default: null, check: { least: 0, step: 1 } },
        { name: 'currency', kind: 'Text', required: true, nullable: false, doc: 'ISO 4217', default: 'USD', check: { shortest: 3, longest: 3 } },
        { name: 'status', kind: 'Text', required: true, nullable: false, doc: 'status', default: 'pending', check: { options: ['pending', 'completed', 'failed', 'refunded'] } },
        { name: 'method', kind: 'Text', required: true, nullable: false, doc: 'payment method', default: null, check: { options: ['card', 'bank', 'crypto'] } },
        { name: 'createdAt', kind: 'Stamp', required: true, nullable: false, doc: 'created time', default: null, check: {} },
      ],
    },
  },
  {
    name: 'User Profile',
    model: {
      name: 'Profile', doc: 'user profile', fields: [
        { name: 'userId', kind: 'Big', required: true, nullable: false, doc: 'user ID', default: null, check: { unique: true } },
        { name: 'displayName', kind: 'Text', required: true, nullable: false, doc: 'display name', default: null, check: { shortest: 1, longest: 50 } },
        { name: 'bio', kind: 'Text', required: false, nullable: true, doc: 'biography', default: null, check: { longest: 500 } },
        { name: 'avatarUrl', kind: 'Text', required: false, nullable: true, doc: 'avatar URL', default: null, check: { format: 'uri' } },
        { name: 'website', kind: 'Text', required: false, nullable: true, doc: 'website', default: null, check: { format: 'uri' } },
        { name: 'isPublic', kind: 'Bool', required: true, nullable: false, doc: 'public profile', default: true, check: {} },
        { name: 'joinedAt', kind: 'Stamp', required: true, nullable: false, doc: 'join date', default: null, check: {} },
      ],
    },
  },
  {
    name: 'Event / Analytics',
    model: {
      name: 'Event', doc: 'analytics event', fields: [
        { name: 'eventId', kind: 'Big', required: true, nullable: false, doc: 'event ID', default: null, check: { unique: true } },
        { name: 'eventType', kind: 'Text', required: true, nullable: false, doc: 'event type', default: null, check: { pattern: '^[a-z_]+$' } },
        { name: 'userId', kind: 'Big', required: false, nullable: true, doc: 'user ID', default: null, check: {} },
        { name: 'properties', kind: { dict: 'Text' }, required: false, nullable: false, doc: 'event properties', default: null, check: {} },
        { name: 'timestamp', kind: 'Stamp', required: true, nullable: false, doc: 'event time', default: null, check: {} },
        { name: 'sessionId', kind: 'Text', required: false, nullable: false, doc: 'session ID', default: null, check: { format: 'uuid' } },
      ],
    },
  },
  {
    name: 'Inventory Item',
    model: {
      name: 'InventoryItem', doc: 'warehouse inventory', fields: [
        { name: 'sku', kind: 'Text', required: true, nullable: false, doc: 'SKU code', default: null, check: { unique: true, pattern: '^[A-Z0-9-]+$' } },
        { name: 'name', kind: 'Text', required: true, nullable: false, doc: 'item name', default: null, check: { shortest: 1, longest: 100 } },
        { name: 'quantity', kind: 'Int', required: true, nullable: false, doc: 'stock quantity', default: 0, check: { least: 0 } },
        { name: 'price', kind: 'Real', required: true, nullable: false, doc: 'unit price', default: null, check: { least: 0, step: 0.01 } },
        { name: 'warehouse', kind: 'Text', required: true, nullable: false, doc: 'warehouse location', default: null, check: { options: ['east', 'west', 'central'] } },
      ],
    },
  },
  {
    name: 'API Key',
    model: {
      name: 'ApiKey', doc: 'API access key', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'key ID', default: null, check: { unique: true } },
        { name: 'keyHash', kind: 'Text', required: true, nullable: false, doc: 'hashed key', default: null, check: { unique: true, longest: 128 } },
        { name: 'name', kind: 'Text', required: true, nullable: false, doc: 'key name', default: null, check: { shortest: 1, longest: 50 } },
        { name: 'scopes', kind: { list: 'Text' }, required: false, nullable: false, doc: 'permissions', default: null, check: { distinct: true } },
        { name: 'expiresAt', kind: 'Stamp', required: false, nullable: true, doc: 'expiry', default: null, check: {} },
        { name: 'isActive', kind: 'Bool', required: true, nullable: false, doc: 'active', default: true, check: {} },
      ],
    },
  },
  {
    name: 'Notification',
    model: {
      name: 'Notification', doc: 'user notification', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'notification ID', default: null, check: { unique: true } },
        { name: 'title', kind: 'Text', required: true, nullable: false, doc: 'title', default: null, check: { shortest: 1, longest: 200 } },
        { name: 'body', kind: 'Text', required: true, nullable: false, doc: 'message body', default: null, check: { longest: 2000 } },
        { name: 'channel', kind: 'Text', required: true, nullable: false, doc: 'delivery channel', default: null, check: { options: ['email', 'sms', 'push', 'inapp'] } },
        { name: 'read', kind: 'Bool', required: true, nullable: false, doc: 'read status', default: false, check: {} },
        { name: 'sentAt', kind: 'Stamp', required: true, nullable: false, doc: 'sent time', default: null, check: {} },
      ],
    },
  },
  {
    name: 'Shipping Label',
    model: {
      name: 'Shipment', doc: 'shipping label', fields: [
        { name: 'trackingNumber', kind: 'Text', required: true, nullable: false, doc: 'tracking number', default: null, check: { unique: true, pattern: '^[A-Z0-9]+$' } },
        { name: 'carrier', kind: 'Text', required: true, nullable: false, doc: 'carrier', default: null, check: { options: ['fedex', 'ups', 'usps', 'dhl'] } },
        { name: 'weight', kind: 'Real', required: true, nullable: false, doc: 'weight in kg', default: null, check: { over: 0, step: 0.01 } },
        { name: 'destination', kind: 'Text', required: true, nullable: false, doc: 'destination address', default: null, check: { shortest: 10, longest: 500 } },
        { name: 'shippedAt', kind: 'Stamp', required: true, nullable: false, doc: 'ship date', default: null, check: {} },
        { name: 'delivered', kind: 'Bool', required: true, nullable: false, doc: 'delivered', default: false, check: {} },
      ],
    },
  },
  {
    name: 'Survey Response',
    model: {
      name: 'SurveyResponse', doc: 'survey response', fields: [
        { name: 'id', kind: 'Big', required: true, nullable: false, doc: 'response ID', default: null, check: { unique: true } },
        { name: 'questionId', kind: 'Big', required: true, nullable: false, doc: 'question ID', default: null, check: {} },
        { name: 'answer', kind: 'Text', required: true, nullable: false, doc: 'answer text', default: null, check: { longest: 5000 } },
        { name: 'rating', kind: 'Int', required: false, nullable: true, doc: 'rating 1-10', default: null, check: { least: 1, most: 10 } },
        { name: 'choices', kind: { list: 'Text' }, required: false, nullable: false, doc: 'selected choices', default: null, check: { distinct: true } },
        { name: 'submittedAt', kind: 'Stamp', required: true, nullable: false, doc: 'submit time', default: null, check: {} },
      ],
    },
  },
];

interface TemplateProps {
  onSelect: (model: ModelInput) => void;
}

export function TemplateLibrary({ onSelect }: TemplateProps) {
  return (
    <details className="mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-500 dark:text-slate-400 select-none font-medium">
        Template Library ({TEMPLATES.length})
      </summary>
      <div className="mt-2 grid grid-cols-1 gap-1">
        {TEMPLATES.map((t, i) => (
          <button
            key={i}
            className="text-left px-2 py-1.5 bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 rounded border border-slate-200 dark:border-slate-700"
            onClick={() => onSelect(t.model as ModelInput)}
          >
            <div className="font-medium">{t.name}</div>
            <div className="text-[10px] text-slate-400">{t.model.fields.length} fields</div>
          </button>
        ))}
      </div>
    </details>
  );
}

