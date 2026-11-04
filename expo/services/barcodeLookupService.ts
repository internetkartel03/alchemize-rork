/**
 * Barcode product lookup via Open Food Facts.
 *
 * Used by the calorie scanner so a scanned barcode fills in the product name and
 * nutrition values instead of forcing the user to type everything by hand. The
 * lookup is best-effort: any failure returns null and the manual form still works.
 */

export interface BarcodeProduct {
  name: string;
  brand: string | null;
  servingSize: string | null;
  calories: number | null;
  protein: number | null;
  carbs: number | null;
  fat: number | null;
  fiber: number | null;
}

const ENDPOINT = 'https://world.openfoodfacts.org/api/v2/product';
const FIELDS = [
  'product_name',
  'generic_name',
  'brands',
  'serving_size',
  'nutriments',
].join(',');

function toNumber(value: unknown): number | null {
  const parsed = typeof value === 'number' ? value : parseFloat(String(value ?? ''));
  return Number.isFinite(parsed) ? Math.round(parsed * 10) / 10 : null;
}

function pickServing(nutriments: Record<string, unknown>, key: string): number | null {
  return toNumber(nutriments[`${key}_serving`]) ?? toNumber(nutriments[`${key}_100g`]);
}

export async function lookupBarcodeProduct(code: string): Promise<BarcodeProduct | null> {
  const trimmed = code.trim();
  if (!trimmed) return null;

  try {
    const response = await fetch(`${ENDPOINT}/${encodeURIComponent(trimmed)}.json?fields=${FIELDS}`, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) return null;

    const payload = await response.json();
    if (!payload || payload.status !== 1 || !payload.product) return null;

    const product = payload.product;
    const nutriments = product.nutriments ?? {};
    const name = String(product.product_name || product.generic_name || '').trim();
    if (!name) return null;

    return {
      name,
      brand: product.brands ? String(product.brands).split(',')[0].trim() : null,
      servingSize: product.serving_size ? String(product.serving_size).trim() : null,
      calories: pickServing(nutriments, 'energy-kcal'),
      protein: pickServing(nutriments, 'proteins'),
      carbs: pickServing(nutriments, 'carbohydrates'),
      fat: pickServing(nutriments, 'fat'),
      fiber: pickServing(nutriments, 'fiber'),
    };
  } catch (error) {
    console.warn('[BarcodeLookup] Lookup failed:', error);
    return null;
  }
}
