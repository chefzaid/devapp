import { InjectionToken } from '@angular/core';
import { environment } from '../environments/environment';

export interface RuntimeConfig {
  readonly keycloakUrl: string;
  readonly keycloakRealm: string;
  readonly keycloakClientId: string;
}

export const RUNTIME_CONFIG = new InjectionToken<RuntimeConfig | null>('DevApp runtime configuration', {
  providedIn: 'root',
  factory: () => {
    if (environment.authEnabled) {
      throw new Error('Runtime configuration must be loaded before authentication starts.');
    }
    return null;
  }
});

export function validateRuntimeConfig(value: unknown, origin: string): RuntimeConfig {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Runtime configuration must be a JSON object.');
  }
  const config = value as Record<string, unknown>;
  const fields = ['keycloakClientId', 'keycloakRealm', 'keycloakUrl'];
  if (Object.keys(config).sort().join(',') !== fields.join(',')) {
    throw new Error('Runtime configuration must contain only keycloakUrl, keycloakRealm and keycloakClientId.');
  }
  const keycloakUrl = config['keycloakUrl'];
  const keycloakRealm = config['keycloakRealm'];
  const keycloakClientId = config['keycloakClientId'];
  if (typeof keycloakUrl !== 'string' || !keycloakUrl.trim() || keycloakUrl.length > 2048 ||
      typeof keycloakRealm !== 'string' || !/^[A-Za-z0-9._-]{1,255}$/.test(keycloakRealm) ||
      typeof keycloakClientId !== 'string' || !/^[A-Za-z0-9._-]{1,255}$/.test(keycloakClientId)) {
    throw new Error('Runtime configuration contains an invalid identity setting.');
  }
  const url = new URL(keycloakUrl, origin);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash ||
      (new URL(origin).protocol === 'https:' && url.protocol !== 'https:')) {
    throw new Error('Keycloak must use an HTTP(S) URL without credentials, query or fragment, and HTTPS on HTTPS pages.');
  }
  return Object.freeze({
    keycloakUrl: url.toString().replace(/\/$/, ''),
    keycloakRealm,
    keycloakClientId
  });
}

export async function loadRuntimeConfig(
  origin: string,
  fetchConfig: typeof fetch = fetch
): Promise<RuntimeConfig> {
  const response = await fetchConfig('/runtime-config.json', {
    cache: 'no-store',
    credentials: 'same-origin',
    redirect: 'error',
    signal: AbortSignal.timeout(10000)
  });
  if (!response.ok) {
    throw new Error(`Runtime configuration request failed (${response.status}).`);
  }
  return validateRuntimeConfig(await response.json(), origin);
}
