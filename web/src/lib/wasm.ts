// WASM 内核加载与调用封装
// 通过 js-string builtins 直接传字符串，无需解码开销

import type { KernelInput, KernelOutput, PresetModel, ModelInput } from './types';

interface ProjDeskExports {
  project_from_json(input: string): string;
  get_presets_json(): string;
  import_from_json_schema_str(text: string): string;
  dsl_project(dsl: string): string;
  solve_constraints(model_json: string): string;
  generate_migration(old_json: string, new_json: string): string;
  check_equivalence(a_json: string, b_json: string): string;
  verify_roundtrip(model_json: string): string;
  verify_roundtrip_dsl(dsl: string): string;
  dsl_to_model(dsl: string): string;
  check_semantics(dsl: string): string;
}

let exportsPromise: Promise<ProjDeskExports> | null = null;

/** 加载 WASM 内核 */
async function loadKernel(): Promise<ProjDeskExports> {
  const response = await fetch(import.meta.env.BASE_URL + 'projdesk.wasm');
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
    exportsPromise = loadKernel().catch((e) => {
      exportsPromise = null; // Reset for retry
      throw e;
    });
  }
  return exportsPromise;
}

/** 调用七投影 */
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

export async function importFromSchema(schemaText: string): Promise<ModelInput> {
  const kernel = await getKernel();
  const modelJson = kernel.import_from_json_schema_str(schemaText);
  return JSON.parse(modelJson) as ModelInput;
}

export async function dslProject(dsl: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.dsl_project(dsl);
}

export async function solveConstraints(modelJson: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.solve_constraints(modelJson);
}

export async function generateMigration(oldJson: string, newJson: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.generate_migration(oldJson, newJson);
}

export async function checkEquivalence(aJson: string, bJson: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.check_equivalence(aJson, bJson);
}

export async function verifyRoundtrip(modelJson: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.verify_roundtrip(modelJson);
}

export async function verifyRoundtripDsl(dsl: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.verify_roundtrip_dsl(dsl);
}

export async function checkSemantics(dsl: string): Promise<string> {
  const kernel = await getKernel();
  return kernel.check_semantics(dsl);
}
