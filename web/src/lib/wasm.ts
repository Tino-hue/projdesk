// WASM 内核加载与调用封装
// 通过 js-string builtins 直接传字符串，零编解码开销

import type { KernelInput, KernelOutput, PresetModel } from './types';

interface ProjDeskExports {
  project_from_json(input: string): string;
  get_presets_json(): string;
}

let exportsPromise: Promise<ProjDeskExports> | null = null;

/** 加载 WASM 内核 */
async function loadKernel(): Promise<ProjDeskExports> {
  const response = await fetch('/projdesk.wasm');
  // wasm-gc + js-string builtins 需要 compileOptions
  const compileOptions = {
    builtins: ['js-string'],
    importedStringConstants: '_',
  };
  const result = await (WebAssembly as unknown as {
    instantiateStreaming(
      source: Response,
      imports: WebAssembly.Imports,
      options: typeof compileOptions,
    ): Promise<WebAssembly.WebAssemblyInstantiatedSource>;
  }).instantiateStreaming(response, {} as WebAssembly.Imports, compileOptions);
  return result.instance.exports as unknown as ProjDeskExports;
}

/** 获取内核实例（懒加载 + 缓存） */
export async function getKernel(): Promise<ProjDeskExports> {
  if (!exportsPromise) {
    exportsPromise = loadKernel();
  }
  return exportsPromise;
}

/** 调用四投影 */
export async function project(input: KernelInput): Promise<KernelOutput> {
  const kernel = await getKernel();
  const resultJson = kernel.project_from_json(JSON.stringify(input));
  return JSON.parse(resultJson) as KernelOutput;
}

/** 获取预设模型 */
export async function getPresets(): Promise<PresetModel[]> {
  const kernel = await getKernel();
  const presetsJson = kernel.get_presets_json();
  return JSON.parse(presetsJson) as PresetModel[];
}
