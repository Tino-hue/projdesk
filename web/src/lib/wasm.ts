// WASM 鍐呮牳鍔犺浇涓庤皟鐢ㄥ皝瑁?// 閫氳繃 js-string builtins 鐩存帴浼犲瓧绗︿覆锛岄浂缂栬В鐮佸紑閿€

import type { KernelInput, KernelOutput, PresetModel } from './types';

interface ProjDeskExports {
  project_from_json(input: string): string;
  get_presets_json(): string;
}

let exportsPromise: Promise<ProjDeskExports> | null = null;

/** 鍔犺浇 WASM 鍐呮牳 */
async function loadKernel(): Promise<ProjDeskExports> {
  const response = await fetch(import.meta.env.BASE_URL + 'projdesk.wasm');
  // wasm-gc + js-string builtins 闇€瑕?compileOptions
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

/** 鑾峰彇鍐呮牳瀹炰緥锛堟噿鍔犺浇 + 缂撳瓨锛?*/
export async function getKernel(): Promise<ProjDeskExports> {
  if (!exportsPromise) {
    exportsPromise = loadKernel();
  }
  return exportsPromise;
}

/** 璋冪敤鍥涙姇褰?*/
export async function project(input: KernelInput): Promise<KernelOutput> {
  const kernel = await getKernel();
  const resultJson = kernel.project_from_json(JSON.stringify(input));
  return JSON.parse(resultJson) as KernelOutput;
}

/** 鑾峰彇棰勮妯″瀷 */
export async function getPresets(): Promise<PresetModel[]> {
  const kernel = await getKernel();
  const presetsJson = kernel.get_presets_json();
  return JSON.parse(presetsJson) as PresetModel[];
}

