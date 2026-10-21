import { useEffect, useRef } from 'react';
import type { ModelInput, TypeSpec } from '../lib/types';

interface Props {
  model: ModelInput;
  known: ModelInput[];
}

interface Node {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
  label: string;
  fields: string[];
  isRef: boolean;
}

function extractRefs(kind: TypeSpec): string[] {
  if (typeof kind === 'object' && kind !== null) {
    if ('ref' in kind) return [kind.ref];
    if ('list' in kind) return extractRefs(kind.list);
    if ('dict' in kind) return extractRefs(kind.dict);
    if ('nest' in kind) {
      return kind.nest.fields.flatMap((f) => extractRefs(f.kind));
    }
  }
  return [];
}

export function ModelDiagram({ model, known }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const W = canvas.width;
    const H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    // Build nodes: main model + referenced models
    const nodes: Map<string, Node> = new Map();
    const mainFields = model.fields.map((f) => f.name + ': ' + (typeof f.kind === 'string' ? f.kind : JSON.stringify(f.kind)));
    nodes.set(model.name, {
      id: model.name,
      x: 40,
      y: 30,
      w: 200,
      h: 40 + mainFields.length * 16,
      label: model.name,
      fields: mainFields,
      isRef: false,
    });

    // Collect all Ref targets
    const refNames = new Set<string>();
    for (const f of model.fields) {
      for (const r of extractRefs(f.kind)) refNames.add(r);
    }

    // Position referenced models to the right
    let refY = 30;
    for (const name of refNames) {
      const m = known.find((k) => k.name === name);
      const fields = m ? m.fields.map((f) => f.name + ': ' + (typeof f.kind === 'string' ? f.kind : '...')) : ['(undefined)'];
      nodes.set(name, {
        id: name,
        x: 320,
        y: refY,
        w: 180,
        h: 40 + fields.length * 16,
        label: name,
        fields,
        isRef: true,
      });
      refY += 40 + fields.length * 16 + 24;
    }

    // Draw edges (main -> refs)
    const main = nodes.get(model.name)!;
    for (const name of refNames) {
      const target = nodes.get(name)!;
      drawArrow(ctx, main.x + main.w, main.y + 20, target.x, target.y + 20);
    }

    // Draw nodes
    for (const node of nodes.values()) {
      drawNode(ctx, node);
    }

    // Legend
    ctx.fillStyle = '#94a3b8';
    ctx.font = '10px sans-serif';
    ctx.fillText('● = model   → = Ref reference   fields listed below', 40, H - 12);
  }, [model, known]);

  return (
    <details className="mx-4 mb-4 text-xs">
      <summary className="cursor-pointer text-slate-500 select-none font-medium">
        Model Relationship Diagram
      </summary>
      <div className="mt-2 border border-slate-200 rounded-lg overflow-hidden bg-slate-50">
        <canvas ref={canvasRef} width={560} height={320} className="w-full" />
      </div>
    </details>
  );
}

function drawNode(ctx: CanvasRenderingContext2D, node: Node) {
  const r = 8;
  const x = node.x;
  const y = node.y;
  const w = node.w;
  const h = node.h;

  // Shadow
  ctx.fillStyle = 'rgba(0,0,0,0.06)';
  ctx.beginPath();
  ctx.roundRect(x + 2, y + 2, w, h, r);
  ctx.fill();

  // Body
  ctx.fillStyle = node.isRef ? '#e0e7ff' : '#dbeafe';
  ctx.strokeStyle = node.isRef ? '#818cf8' : '#3b82f6';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
  ctx.fill();
  ctx.stroke();

  // Title bar
  ctx.fillStyle = node.isRef ? '#6366f1' : '#2563eb';
  ctx.beginPath();
  ctx.roundRect(x, y, w, 28, r);
  ctx.fill();
  // Cover bottom radius of title
  ctx.fillRect(x, y + 14, w, 14);

  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 11px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(node.label, x + w / 2, y + 18);
  ctx.textAlign = 'left';

  // Fields
  ctx.fillStyle = '#334155';
  ctx.font = '9px monospace';
  node.fields.forEach((f, i) => {
    ctx.fillText(f, x + 8, y + 42 + i * 16);
  });
}

function drawArrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number) {
  const midX = (x1 + x2) / 2;
  ctx.strokeStyle = '#94a3b8';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.bezierCurveTo(midX, y1, midX, y2, x2 - 8, y2);
  ctx.stroke();

  // Arrowhead
  ctx.fillStyle = '#94a3b8';
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 8, y2 - 4);
  ctx.lineTo(x2 - 8, y2 + 4);
  ctx.closePath();
  ctx.fill();
}
